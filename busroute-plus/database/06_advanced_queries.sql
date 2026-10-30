USE busroute_plus;

-- 1. Route stops in order
SELECT r.route_no, s.name_en, s.name_ta, rs.seq, rs.offset_min,
       s.verification_status, s.confirmation_count
FROM routes r
JOIN route_stops rs ON rs.route_id = r.route_id
JOIN stops s ON s.stop_id = rs.stop_id
ORDER BY r.route_no, rs.seq;

-- 2. Search route between two stops (source must occur before destination)
SELECT r.route_no, r.name,
       s1.name_en AS origin, s2.name_en AS destination,
       rs2.offset_min - rs1.offset_min AS travel_minutes
FROM routes r
JOIN route_stops rs1 ON rs1.route_id = r.route_id
JOIN stops s1 ON s1.stop_id = rs1.stop_id
JOIN route_stops rs2 ON rs2.route_id = r.route_id AND rs2.seq > rs1.seq
JOIN stops s2 ON s2.stop_id = rs2.stop_id
WHERE LOWER(s1.name_en) LIKE '%guindy%'
  AND LOWER(s2.name_en) LIKE '%tambaram%'
ORDER BY travel_minutes;

-- 3. Trust-weighted average delay in last 24 hours
SELECT r.route_no,
       ROUND(SUM(d.delay_minutes * d.user_trust_score) /
             NULLIF(SUM(d.user_trust_score),0), 2) AS weighted_avg_delay
FROM routes r
JOIN delay_reports d ON d.route_id = r.route_id
WHERE d.is_valid = TRUE AND d.reported_at >= NOW() - INTERVAL 24 HOUR
GROUP BY r.route_id, r.route_no
ORDER BY weighted_avg_delay DESC;

-- 4. Crowd-level distribution
SELECT r.route_no, c.crowd_level, COUNT(*) AS report_count,
       ROUND(AVG(c.crowd_percent),1) AS average_crowd_percent
FROM crowd_reports c
JOIN routes r ON r.route_id = c.route_id
GROUP BY r.route_no, c.crowd_level
ORDER BY r.route_no, report_count DESC;

-- 5. Routes with average delay greater than five minutes
SELECT r.route_no, ROUND(AVG(d.delay_minutes),2) AS avg_delay, COUNT(*) AS reports
FROM routes r JOIN delay_reports d ON d.route_id = r.route_id
WHERE d.is_valid = TRUE
GROUP BY r.route_id, r.route_no
HAVING AVG(d.delay_minutes) > 5
ORDER BY avg_delay DESC;

-- 6. Reliability ranking using a window function
WITH route_scores AS (
  SELECT r.route_id, r.route_no,
         COALESCE(AVG(d.delay_minutes),0) AS avg_delay,
         COUNT(d.report_id) AS report_count
  FROM routes r LEFT JOIN delay_reports d
    ON d.route_id = r.route_id AND d.is_valid = TRUE
  GROUP BY r.route_id, r.route_no
)
SELECT route_no, ROUND(avg_delay,2) AS avg_delay, report_count,
       RANK() OVER (ORDER BY avg_delay ASC) AS reliability_rank
FROM route_scores
ORDER BY reliability_rank;

-- 7. Top community contributors
SELECT u.user_id, u.full_name, u.trust_score, COUNT(d.report_id) AS report_count
FROM users u LEFT JOIN delay_reports d ON d.user_id = u.user_id
GROUP BY u.user_id, u.full_name, u.trust_score
ORDER BY u.trust_score DESC, report_count DESC
LIMIT 10;

-- 8. Active diversions
SELECT r.route_no, r.name, d.reason, d.note_en, d.note_ta, d.start_time, d.end_time
FROM diversions d JOIN routes r ON r.route_id = d.route_id
WHERE d.is_active = TRUE
  AND d.start_time <= NOW()
  AND (d.end_time IS NULL OR d.end_time >= NOW());

-- 9. Data-quality anomaly candidates: route delay above mean + 2 standard deviations
WITH route_avg AS (
  SELECT route_id, AVG(delay_minutes) AS avg_delay
  FROM delay_reports
  WHERE is_valid = TRUE AND reported_at >= NOW() - INTERVAL 24 HOUR
  GROUP BY route_id
),
stats AS (
  SELECT AVG(avg_delay) AS overall_avg, STDDEV_POP(avg_delay) AS overall_sd
  FROM route_avg
)
SELECT r.route_no, ROUND(a.avg_delay,2) AS avg_delay
FROM route_avg a
JOIN routes r ON r.route_id = a.route_id
CROSS JOIN stats s
WHERE a.avg_delay > s.overall_avg + 2 * s.overall_sd;

-- 10. Current live bus status view
SELECT * FROM v_live_bus_status ORDER BY route_no, bus_number;

-- 11. Route/stops lookup using case-insensitive search
SELECT stop_id, name_en, name_ta
FROM stops
WHERE LOWER(TRIM(name_en)) LIKE '%srm%'
   OR name_ta LIKE '%எஸ்.ஆர்.எம்.%';

-- 12. Fare estimate for a 4-stage student journey
CALL sp_get_fare(4, 'student');

-- 13. Nearest stops to an example coordinate (Chennai)
CALL sp_nearest_stops(13.0827, 80.2755, 5);

-- 14. Route search procedure
CALL sp_search_routes('Guindy', 'Tambaram', NULL);

-- 15. Summary KPIs
SELECT
  (SELECT COUNT(*) FROM routes) AS route_count,
  (SELECT COUNT(*) FROM stops) AS stop_count,
  (SELECT COUNT(*) FROM buses) AS bus_count,
  (SELECT COUNT(*) FROM delay_reports WHERE reported_at >= NOW() - INTERVAL 24 HOUR) AS recent_delay_reports,
  (SELECT COUNT(*) FROM stops WHERE verification_status='VERIFIED') AS verified_stops;
