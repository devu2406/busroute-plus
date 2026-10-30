USE busroute_plus;

CREATE OR REPLACE VIEW v_live_bus_status AS
SELECT
  b.bus_id, b.bus_number, r.route_id, r.route_no, r.name AS route_name,
  b.crowd_percent,
  COALESCE(ROUND(
    SUM(dr.delay_minutes * dr.user_trust_score) /
    NULLIF(SUM(dr.user_trust_score), 0), 1
  ), 0) AS trust_weighted_delay_min,
  COUNT(DISTINCT dr.report_id) AS delay_report_count,
  (r.is_diverted OR EXISTS (
    SELECT 1 FROM diversions d
    WHERE d.route_id = r.route_id
      AND d.is_active = TRUE
      AND d.start_time <= NOW()
      AND (d.end_time IS NULL OR d.end_time >= NOW())
  )) AS is_currently_diverted
FROM buses b
JOIN routes r ON r.route_id = b.route_id
LEFT JOIN delay_reports dr
  ON dr.route_id = r.route_id
 AND dr.is_valid = TRUE
 AND dr.reported_at >= NOW() - INTERVAL 24 HOUR
GROUP BY b.bus_id, b.bus_number, r.route_id, r.route_no, r.name,
         b.crowd_percent, r.is_diverted;

CREATE OR REPLACE VIEW v_route_reliability AS
SELECT
  r.route_id, r.route_no, r.name,
  COUNT(dr.report_id) AS report_count,
  COALESCE(ROUND(AVG(dr.delay_minutes), 2), 0) AS avg_delay_min,
  COALESCE(ROUND(
    SUM(dr.delay_minutes * dr.user_trust_score) /
    NULLIF(SUM(dr.user_trust_score), 0), 2
  ), 0) AS trust_weighted_delay_min,
  COALESCE(ROUND(AVG(cr.crowd_percent), 1), 0) AS avg_crowd_percent
FROM routes r
LEFT JOIN delay_reports dr
  ON dr.route_id = r.route_id AND dr.is_valid = TRUE
LEFT JOIN crowd_reports cr
  ON cr.route_id = r.route_id
GROUP BY r.route_id, r.route_no, r.name;
