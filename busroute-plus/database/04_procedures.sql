USE busroute_plus;

DROP PROCEDURE IF EXISTS sp_search_routes;
DROP PROCEDURE IF EXISTS sp_get_fare;
DROP PROCEDURE IF EXISTS sp_nearest_stops;
DROP PROCEDURE IF EXISTS sp_submit_delay_report;

DELIMITER $$

CREATE PROCEDURE sp_search_routes(
  IN p_from VARCHAR(120),
  IN p_to VARCHAR(120),
  IN p_route_no VARCHAR(20)
)
BEGIN
  SELECT r.route_id, r.route_no, r.name, r.color,
         s1.stop_id AS from_stop_id, s1.name_en AS from_stop,
         s2.stop_id AS to_stop_id, s2.name_en AS to_stop,
         (rs2.offset_min - rs1.offset_min) AS travel_min,
         r.is_diverted
  FROM routes r
  JOIN route_stops rs1 ON rs1.route_id = r.route_id
  JOIN stops s1 ON s1.stop_id = rs1.stop_id
  JOIN route_stops rs2 ON rs2.route_id = r.route_id AND rs2.seq > rs1.seq
  JOIN stops s2 ON s2.stop_id = rs2.stop_id
  WHERE (p_from IS NULL OR p_from = '' OR LOWER(s1.name_en) LIKE CONCAT('%',LOWER(p_from),'%')
         OR s1.name_ta LIKE CONCAT('%',p_from,'%'))
    AND (p_to IS NULL OR p_to = '' OR LOWER(s2.name_en) LIKE CONCAT('%',LOWER(p_to),'%')
         OR s2.name_ta LIKE CONCAT('%',p_to,'%'))
    AND (p_route_no IS NULL OR p_route_no = '' OR LOWER(r.route_no) LIKE CONCAT('%',LOWER(p_route_no),'%'))
  ORDER BY travel_min, r.route_no;
END$$

CREATE PROCEDURE sp_get_fare(
  IN p_hops INT,
  IN p_category VARCHAR(20)
)
BEGIN
  SELECT p_hops AS stages,
         passenger_category,
         ROUND((base_fare + per_stage * GREATEST(p_hops - 1, 0)) * multiplier, 2) AS estimated_fare
  FROM fare_rules
  WHERE passenger_category = LOWER(p_category);
END$$

CREATE PROCEDURE sp_nearest_stops(
  IN p_lat DECIMAL(10,7),
  IN p_lng DECIMAL(10,7),
  IN p_limit INT
)
BEGIN
  SELECT stop_id, name_en, name_ta, latitude, longitude, verification_status,
    ROUND(6371 * 2 * ASIN(SQRT(
      POWER(SIN(RADIANS(latitude - p_lat) / 2), 2) +
      COS(RADIANS(p_lat)) * COS(RADIANS(latitude)) *
      POWER(SIN(RADIANS(longitude - p_lng) / 2), 2)
    )), 3) AS distance_km
  FROM stops
  ORDER BY distance_km
  LIMIT p_limit;
END$$

CREATE PROCEDURE sp_submit_delay_report(
  IN p_route_id INT,
  IN p_user_id INT,
  IN p_delay_minutes INT,
  IN p_note VARCHAR(500)
)
BEGIN
  DECLARE v_trust INT DEFAULT 50;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
  SELECT trust_score INTO v_trust FROM users WHERE user_id = p_user_id FOR UPDATE;
  INSERT INTO delay_reports(route_id,user_id,delay_minutes,user_trust_score,report_note)
  VALUES(p_route_id,p_user_id,p_delay_minutes,v_trust,p_note);
  COMMIT;
  SELECT 'Report saved' AS message, v_trust AS trust_score;
END$$

DELIMITER ;
