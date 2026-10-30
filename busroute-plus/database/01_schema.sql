-- BusRoute+ schema | MySQL 8.0+
CREATE DATABASE IF NOT EXISTS busroute_plus
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE busroute_plus;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS v_live_bus_status;
DROP VIEW IF EXISTS v_route_reliability;
DROP TABLE IF EXISTS stop_confirmations;
DROP TABLE IF EXISTS stop_corrections;
DROP TABLE IF EXISTS crowd_reports;
DROP TABLE IF EXISTS delay_reports;
DROP TABLE IF EXISTS diversions;
DROP TABLE IF EXISTS fare_rules;
DROP TABLE IF EXISTS buses;
DROP TABLE IF EXISTS route_stops;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS stops;
DROP TABLE IF EXISTS routes;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE routes (
  route_id INT AUTO_INCREMENT PRIMARY KEY,
  route_no VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(180) NOT NULL,
  color VARCHAR(20) NOT NULL DEFAULT '#14213d',
  first_departure TIME NOT NULL DEFAULT '05:00:00',
  frequency_min INT NOT NULL DEFAULT 15,
  last_departure TIME NOT NULL DEFAULT '22:00:00',
  is_diverted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (frequency_min > 0)
) ENGINE=InnoDB;

CREATE TABLE stops (
  stop_id INT AUTO_INCREMENT PRIMARY KEY,
  name_en VARCHAR(120) NOT NULL,
  name_ta VARCHAR(160) NOT NULL,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  verification_status ENUM('PENDING','VERIFIED') NOT NULL DEFAULT 'PENDING',
  confirmation_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (confirmation_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(180) NOT NULL UNIQUE,
  trust_score TINYINT UNSIGNED NOT NULL DEFAULT 50,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (trust_score <= 100)
) ENGINE=InnoDB;

CREATE TABLE route_stops (
  route_stop_id INT AUTO_INCREMENT PRIMARY KEY,
  route_id INT NOT NULL,
  stop_id INT NOT NULL,
  seq INT NOT NULL,
  offset_min INT NOT NULL DEFAULT 0,
  scheduled_time TIME NULL,
  UNIQUE KEY uq_route_seq (route_id, seq),
  UNIQUE KEY uq_route_stop (route_id, stop_id),
  CONSTRAINT fk_rs_route FOREIGN KEY (route_id) REFERENCES routes(route_id) ON DELETE CASCADE,
  CONSTRAINT fk_rs_stop FOREIGN KEY (stop_id) REFERENCES stops(stop_id),
  CHECK (seq > 0),
  CHECK (offset_min >= 0)
) ENGINE=InnoDB;

CREATE TABLE buses (
  bus_id INT AUTO_INCREMENT PRIMARY KEY,
  bus_number VARCHAR(40) NOT NULL UNIQUE,
  route_id INT NOT NULL,
  bus_type ENUM('ORDINARY','DELUXE','AC','EXPRESS') NOT NULL DEFAULT 'ORDINARY',
  progress DECIMAL(5,4) NOT NULL DEFAULT 0,
  crowd_percent TINYINT UNSIGNED NOT NULL DEFAULT 0,
  current_latitude DECIMAL(10,7) NULL,
  current_longitude DECIMAL(10,7) NULL,
  last_updated TIMESTAMP NULL,
  CONSTRAINT fk_bus_route FOREIGN KEY (route_id) REFERENCES routes(route_id),
  CHECK (progress >= 0 AND progress <= 1),
  CHECK (crowd_percent <= 100)
) ENGINE=InnoDB;

CREATE TABLE delay_reports (
  report_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  route_id INT NOT NULL,
  stop_id INT NULL,
  user_id INT NULL,
  delay_minutes INT NOT NULL DEFAULT 0,
  user_trust_score TINYINT UNSIGNED NOT NULL DEFAULT 50,
  report_note VARCHAR(500) NULL,
  is_valid BOOLEAN NOT NULL DEFAULT TRUE,
  reported_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_dr_route FOREIGN KEY (route_id) REFERENCES routes(route_id),
  CONSTRAINT fk_dr_stop FOREIGN KEY (stop_id) REFERENCES stops(stop_id),
  CONSTRAINT fk_dr_user FOREIGN KEY (user_id) REFERENCES users(user_id),
  CHECK (delay_minutes >= 0),
  CHECK (user_trust_score <= 100)
) ENGINE=InnoDB;

CREATE TABLE crowd_reports (
  crowd_report_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  route_id INT NOT NULL,
  stop_id INT NULL,
  user_id INT NULL,
  crowd_percent TINYINT UNSIGNED NOT NULL,
  crowd_level ENUM('LOW','MEDIUM','HIGH','FULL') NOT NULL,
  reported_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_cr_route FOREIGN KEY (route_id) REFERENCES routes(route_id),
  CONSTRAINT fk_cr_stop FOREIGN KEY (stop_id) REFERENCES stops(stop_id),
  CONSTRAINT fk_cr_user FOREIGN KEY (user_id) REFERENCES users(user_id),
  CHECK (crowd_percent <= 100)
) ENGINE=InnoDB;

CREATE TABLE stop_corrections (
  correction_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  stop_id INT NOT NULL,
  suggested_name_en VARCHAR(120) NULL,
  suggested_name_ta VARCHAR(160) NULL,
  note VARCHAR(500) NOT NULL,
  confirmation_count INT NOT NULL DEFAULT 1,
  status ENUM('PENDING','VERIFIED','REJECTED') NOT NULL DEFAULT 'PENDING',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_sc_stop FOREIGN KEY (stop_id) REFERENCES stops(stop_id),
  CHECK (confirmation_count >= 0)
) ENGINE=InnoDB;

CREATE TABLE stop_confirmations (
  confirmation_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  correction_id BIGINT NOT NULL,
  user_id INT NOT NULL,
  confirmed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_correction (correction_id, user_id),
  CONSTRAINT fk_confirm_correction FOREIGN KEY (correction_id)
    REFERENCES stop_corrections(correction_id) ON DELETE CASCADE,
  CONSTRAINT fk_confirm_user FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

CREATE TABLE fare_rules (
  fare_rule_id INT AUTO_INCREMENT PRIMARY KEY,
  passenger_category ENUM('general','student','senior','woman') NOT NULL UNIQUE,
  multiplier DECIMAL(5,2) NOT NULL DEFAULT 1.00,
  base_fare DECIMAL(8,2) NOT NULL DEFAULT 5.00,
  per_stage DECIMAL(8,2) NOT NULL DEFAULT 2.00,
  CHECK (multiplier >= 0),
  CHECK (base_fare >= 0),
  CHECK (per_stage >= 0)
) ENGINE=InnoDB;

CREATE TABLE diversions (
  diversion_id INT AUTO_INCREMENT PRIMARY KEY,
  route_id INT NOT NULL,
  reason VARCHAR(500) NOT NULL,
  note_en VARCHAR(500) NULL,
  note_ta VARCHAR(500) NULL,
  start_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  end_time DATETIME NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  affected_stop_id INT NULL,
  CONSTRAINT fk_div_route FOREIGN KEY (route_id) REFERENCES routes(route_id),
  CONSTRAINT fk_div_stop FOREIGN KEY (affected_stop_id) REFERENCES stops(stop_id),
  CHECK (end_time IS NULL OR end_time >= start_time)
) ENGINE=InnoDB;

CREATE INDEX idx_stops_name_en ON stops(name_en);
CREATE INDEX idx_stops_name_ta ON stops(name_ta);
CREATE INDEX idx_route_stops_stop_route ON route_stops(stop_id, route_id);
CREATE INDEX idx_delay_route_time ON delay_reports(route_id, reported_at);
CREATE INDEX idx_crowd_route_time ON crowd_reports(route_id, reported_at);
CREATE INDEX idx_diversion_active_time ON diversions(is_active, start_time, end_time);
