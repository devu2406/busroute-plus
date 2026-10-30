-- BusRoute+ database setup (MySQL 8.0+)
-- Save as database/07_fastapi_database.sql
-- Standalone schema: review against 01_schema.sql before running to avoid conflicts.

CREATE DATABASE IF NOT EXISTS busroute_plus CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE busroute_plus;

CREATE TABLE IF NOT EXISTS routes (
  route_id INT AUTO_INCREMENT PRIMARY KEY,
  route_no VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(180) NOT NULL,
  color VARCHAR(20) NOT NULL DEFAULT '#14213d',
  first_departure TIME NOT NULL DEFAULT '05:00:00',
  frequency_min INT NOT NULL DEFAULT 15,
  last_departure TIME NOT NULL DEFAULT '22:00:00',
  is_diverted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS stops (
  stop_id INT AUTO_INCREMENT PRIMARY KEY,
  name_en VARCHAR(120) NOT NULL,
  name_ta VARCHAR(160) NOT NULL,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  verification_status ENUM('PENDING','VERIFIED') DEFAULT 'PENDING',
  confirmation_count INT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(180) NOT NULL UNIQUE,
  trust_score TINYINT UNSIGNED NOT NULL DEFAULT 50,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS route_stops (
  route_stop_id INT AUTO_INCREMENT PRIMARY KEY,
  route_id INT NOT NULL,
  stop_id INT NOT NULL,
  seq INT NOT NULL,
  offset_min INT NOT NULL DEFAULT 0,
  UNIQUE KEY uq_route_seq(route_id, seq),
  CONSTRAINT fk_rs_route FOREIGN KEY(route_id) REFERENCES routes(route_id),
  CONSTRAINT fk_rs_stop FOREIGN KEY(stop_id) REFERENCES stops(stop_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS buses (
  bus_id INT AUTO_INCREMENT PRIMARY KEY,
  bus_number VARCHAR(40) NOT NULL UNIQUE,
  route_id INT NOT NULL,
  bus_type ENUM('ORDINARY','DELUXE','AC','EXPRESS') DEFAULT 'ORDINARY',
  progress DECIMAL(5,4) DEFAULT 0,
  crowd_percent TINYINT UNSIGNED DEFAULT 0,
  current_latitude DECIMAL(10,7) NULL,
  current_longitude DECIMAL(10,7) NULL,
  last_updated TIMESTAMP NULL,
  CONSTRAINT fk_bus_route FOREIGN KEY(route_id) REFERENCES routes(route_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS delay_reports (
  report_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  route_id INT NOT NULL,
  stop_id INT NULL,
  user_id INT NULL,
  delay_minutes INT NOT NULL DEFAULT 0,
  user_trust_score TINYINT UNSIGNED NOT NULL DEFAULT 50,
  report_note VARCHAR(500) NULL,
  is_valid BOOLEAN NOT NULL DEFAULT TRUE,
  reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_dr_route FOREIGN KEY(route_id) REFERENCES routes(route_id),
  CONSTRAINT fk_dr_stop FOREIGN KEY(stop_id) REFERENCES stops(stop_id),
  CONSTRAINT fk_dr_user FOREIGN KEY(user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS crowd_reports (
  crowd_report_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  route_id INT NOT NULL,
  stop_id INT NULL,
  user_id INT NULL,
  crowd_percent TINYINT UNSIGNED NOT NULL,
  crowd_level ENUM('LOW','MEDIUM','HIGH','FULL') NOT NULL,
  reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_cr_route FOREIGN KEY(route_id) REFERENCES routes(route_id),
  CONSTRAINT fk_cr_stop FOREIGN KEY(stop_id) REFERENCES stops(stop_id),
  CONSTRAINT fk_cr_user FOREIGN KEY(user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS stop_corrections (
  correction_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  stop_id INT NOT NULL,
  suggested_name_en VARCHAR(120) NULL,
  suggested_name_ta VARCHAR(160) NULL,
  note VARCHAR(500) NOT NULL,
  confirmation_count INT NOT NULL DEFAULT 1,
  status ENUM('PENDING','VERIFIED','REJECTED') DEFAULT 'PENDING',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_sc_stop FOREIGN KEY(stop_id) REFERENCES stops(stop_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fare_rules (
  fare_rule_id INT AUTO_INCREMENT PRIMARY KEY,
  passenger_category ENUM('general','student','senior','woman') NOT NULL UNIQUE,
  multiplier DECIMAL(5,2) NOT NULL DEFAULT 1.00,
  base_fare DECIMAL(8,2) NOT NULL DEFAULT 5.00,
  per_stage DECIMAL(8,2) NOT NULL DEFAULT 2.00
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS diversions (
  diversion_id INT AUTO_INCREMENT PRIMARY KEY,
  route_id INT NOT NULL,
  reason VARCHAR(500) NOT NULL,
  note_en VARCHAR(500) NULL,
  note_ta VARCHAR(500) NULL,
  start_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  end_time DATETIME NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  affected_stop_id INT NULL,
  CONSTRAINT fk_div_route FOREIGN KEY(route_id) REFERENCES routes(route_id),
  CONSTRAINT fk_div_stop FOREIGN KEY(affected_stop_id) REFERENCES stops(stop_id)
) ENGINE=InnoDB;

CREATE INDEX idx_stop_name_en ON stops(name_en);
CREATE INDEX idx_stop_name_ta ON stops(name_ta);
CREATE INDEX idx_rs_stop_route ON route_stops(stop_id, route_id);
CREATE INDEX idx_delay_route_time ON delay_reports(route_id, reported_at);
CREATE INDEX idx_crowd_route_time ON crowd_reports(route_id, reported_at);

-- Sample Chennai stops
INSERT IGNORE INTO stops
(stop_id,name_en,name_ta,latitude,longitude,verification_status,confirmation_count) VALUES
(1,'Broadway','பிராட்வே',13.0900,80.2860,'VERIFIED',9),
(2,'Chennai Central','சென்னை சென்ட்ரல்',13.0827,80.2755,'VERIFIED',12),
(3,'Anna Salai','அண்ணா சாலை',13.0620,80.2680,'VERIFIED',7),
(4,'T. Nagar','தி. நகர்',13.0418,80.2341,'VERIFIED',10),
(5,'Guindy','கிண்டி',13.0067,80.2206,'VERIFIED',11),
(6,'Chromepet','குரோம்பேட்டை',12.9516,80.1462,'VERIFIED',8),
(7,'Tambaram','தாம்பரம்',12.9249,80.1000,'VERIFIED',14),
(8,'Perungalathur','பெருங்களத்தூர்',12.9034,80.0905,'VERIFIED',6),
(9,'Vandalur','வண்டலூர்',12.8918,80.0810,'VERIFIED',7),
(10,'Guduvanchery','கூடுவாஞ்சேரி',12.8452,80.0605,'VERIFIED',6),
(11,'Potheri','பொத்தேரி',12.8230,80.0450,'VERIFIED',5),
(12,'SRM University','எஸ்.ஆர்.எம். பல்கலை',12.8230,80.0444,'PENDING',2),
(13,'Maraimalai Nagar','மறைமலை நகர்',12.7940,80.0250,'VERIFIED',8),
(14,'Chengalpattu','செங்கல்பட்டு',12.6819,79.9888,'VERIFIED',13),
(15,'Koyambedu (CMBT)','கோயம்பேடு (சி.எம்.பி.டி)',13.0694,80.1948,'VERIFIED',12),
(16,'Vadapalani','வடபழனி',13.0500,80.2121,'VERIFIED',6);

INSERT IGNORE INTO routes
(route_id,route_no,name,color,first_departure,frequency_min,last_departure,is_diverted) VALUES
(1,'21G','Broadway – Tambaram','#14213d','05:00',15,'22:00',FALSE),
(2,'M70','Tambaram – Chengalpattu (via SRM)','#2563eb','04:45',10,'23:00',FALSE),
(3,'119','Koyambedu – Chengalpattu','#1f9d5b','05:15',20,'21:30',TRUE),
(4,'51B','T. Nagar – Guduvanchery','#e08a1e','05:30',12,'21:45',FALSE),
(5,'T51','Guindy – SRM University','#8b5cf6','06:00',30,'20:30',FALSE);

INSERT IGNORE INTO route_stops(route_id,stop_id,seq,offset_min) VALUES
(1,1,1,0),(1,2,2,8),(1,3,3,20),(1,4,4,38),(1,5,5,52),(1,6,6,78),(1,7,7,90),
(2,7,1,0),(2,8,2,12),(2,9,3,22),(2,10,4,38),(2,11,5,50),(2,12,6,53),(2,13,7,65),(2,14,8,85),
(3,15,1,0),(3,16,2,12),(3,5,3,28),(3,7,4,58),(3,9,5,72),(3,10,6,86),(3,11,7,96),(3,13,8,108),(3,14,9,125),
(4,4,1,0),(4,5,2,14),(4,6,3,40),(4,7,4,52),(4,8,5,64),(4,9,6,74),(4,10,7,90),
(5,5,1,0),(5,6,2,26),(5,7,3,38),(5,9,4,58),(5,10,5,74),(5,11,6,86),(5,12,7,89);

INSERT IGNORE INTO buses(bus_number,route_id,bus_type,progress,crowd_percent) VALUES
('TN01-N-2101',1,'ORDINARY',0.3200,61),('TN01-N-2102',1,'ORDINARY',0.7800,24),
('TN21-N-7010',2,'ORDINARY',0.2000,88),('TN21-N-7011',2,'ORDINARY',0.6200,45),
('TN21-N-1190',3,'ORDINARY',0.4500,30),('TN01-N-5151',4,'ORDINARY',0.5500,72),
('TN21-N-0510',5,'ORDINARY',0.4000,38);

INSERT IGNORE INTO users(full_name,email,trust_score) VALUES ('Demo Passenger','demo@busroute.local',50);

INSERT IGNORE INTO fare_rules(passenger_category,multiplier,base_fare,per_stage) VALUES
('general',1.00,5.00,2.00),('student',0.50,5.00,2.00),
('senior',0.50,5.00,2.00),('woman',0.00,5.00,2.00);

-- Test queries
-- SELECT * FROM routes;
-- SELECT * FROM stops;
-- SELECT r.route_no, s.name_en, rs.seq, rs.offset_min
-- FROM routes r JOIN route_stops rs ON rs.route_id=r.route_id
-- JOIN stops s ON s.stop_id=rs.stop_id ORDER BY r.route_id, rs.seq;
-- SELECT route_id, ROUND(SUM(delay_minutes*user_trust_score)/NULLIF(SUM(user_trust_score),0),1) AS weighted_delay
-- FROM delay_reports WHERE is_valid=TRUE GROUP BY route_id;
