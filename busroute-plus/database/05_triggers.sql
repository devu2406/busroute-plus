USE busroute_plus;

DROP TRIGGER IF EXISTS trg_stop_correction_verified;
DROP TRIGGER IF EXISTS trg_delay_report_trust_snapshot;
DROP TRIGGER IF EXISTS trg_diversion_route_flag;

DELIMITER $$

CREATE TRIGGER trg_stop_correction_verified
AFTER INSERT ON stop_confirmations
FOR EACH ROW
BEGIN
  UPDATE stop_corrections
  SET confirmation_count = (
    SELECT COUNT(*) FROM stop_confirmations
    WHERE correction_id = NEW.correction_id
  )
  WHERE correction_id = NEW.correction_id;

  UPDATE stop_corrections
  SET status = 'VERIFIED'
  WHERE correction_id = NEW.correction_id
    AND confirmation_count >= 3;
END$$

CREATE TRIGGER trg_delay_report_trust_snapshot
BEFORE INSERT ON delay_reports
FOR EACH ROW
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    SET NEW.user_trust_score = COALESCE(
      (SELECT trust_score FROM users WHERE user_id = NEW.user_id), 50
    );
  END IF;
END$$

CREATE TRIGGER trg_diversion_route_flag
AFTER INSERT ON diversions
FOR EACH ROW
BEGIN
  IF NEW.is_active = TRUE THEN
    UPDATE routes SET is_diverted = TRUE WHERE route_id = NEW.route_id;
  END IF;
END$$

DELIMITER ;

-- Note: this trigger records route diversion status as a flag.
-- In a production app, calculate active diversion from start_time/end_time
-- or use a scheduled job to clear is_diverted when the diversion ends.
