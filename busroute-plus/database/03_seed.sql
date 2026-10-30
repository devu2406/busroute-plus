USE busroute_plus;

INSERT INTO stops
(stop_id,name_en,name_ta,latitude,longitude,verification_status,confirmation_count)
VALUES
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

INSERT INTO routes
(route_id,route_no,name,color,first_departure,frequency_min,last_departure,is_diverted)
VALUES
(1,'21G','Broadway – Tambaram','#14213d','05:00',15,'22:00',FALSE),
(2,'M70','Tambaram – Chengalpattu (via SRM)','#2563eb','04:45',10,'23:00',FALSE),
(3,'119','Koyambedu – Chengalpattu','#1f9d5b','05:15',20,'21:30',TRUE),
(4,'51B','T. Nagar – Guduvanchery','#e08a1e','05:30',12,'21:45',FALSE),
(5,'T51','Guindy – SRM University','#8b5cf6','06:00',30,'20:30',FALSE);

INSERT INTO route_stops(route_id,stop_id,seq,offset_min) VALUES
(1,1,1,0),(1,2,2,8),(1,3,3,20),(1,4,4,38),(1,5,5,52),(1,6,6,78),(1,7,7,90),
(2,7,1,0),(2,8,2,12),(2,9,3,22),(2,10,4,38),(2,11,5,50),(2,12,6,53),(2,13,7,65),(2,14,8,85),
(3,15,1,0),(3,16,2,12),(3,5,3,28),(3,7,4,58),(3,9,5,72),(3,10,6,86),(3,11,7,96),(3,13,8,108),(3,14,9,125),
(4,4,1,0),(4,5,2,14),(4,6,3,40),(4,7,4,52),(4,8,5,64),(4,9,6,74),(4,10,7,90),
(5,5,1,0),(5,6,2,26),(5,7,3,38),(5,9,4,58),(5,10,5,74),(5,11,6,86),(5,12,7,89);

INSERT INTO buses(bus_number,route_id,bus_type,progress,crowd_percent) VALUES
('TN01-N-2101',1,'ORDINARY',0.3200,61),
('TN01-N-2102',1,'ORDINARY',0.7800,24),
('TN21-N-7010',2,'ORDINARY',0.2000,88),
('TN21-N-7011',2,'ORDINARY',0.6200,45),
('TN21-N-1190',3,'ORDINARY',0.4500,30),
('TN01-N-5151',4,'ORDINARY',0.5500,72),
('TN21-N-0510',5,'ORDINARY',0.4000,38);

INSERT INTO users(full_name,email,trust_score) VALUES
('Demo Passenger','demo@busroute.local',50);

INSERT INTO fare_rules(passenger_category,multiplier,base_fare,per_stage) VALUES
('general',1.00,5.00,2.00),('student',0.50,5.00,2.00),
('senior',0.50,5.00,2.00),('woman',0.00,5.00,2.00);

INSERT INTO delay_reports(route_id,delay_minutes,user_trust_score,reported_at) VALUES
(2,8,80,NOW()-INTERVAL 6 MINUTE),
(2,12,60,NOW()-INTERVAL 14 MINUTE),
(3,20,90,NOW()-INTERVAL 9 MINUTE),
(3,15,55,NOW()-INTERVAL 22 MINUTE),
(1,4,70,NOW()-INTERVAL 11 MINUTE),
(4,6,50,NOW()-INTERVAL 30 MINUTE),
(5,2,65,NOW()-INTERVAL 18 MINUTE);

INSERT INTO stop_corrections(stop_id,note,confirmation_count,status)
VALUES (12,'Stop is at SRM Main Gate, not Potheri junction',2,'PENDING');

INSERT INTO diversions(route_id,reason,note_en,note_ta,start_time,is_active,affected_stop_id)
VALUES (3,'Road work',
'Diverted via Vadapalani flyover due to road work. Expect +10 min.',
'சாலைப் பணி காரணமாக வடபழனி மேம்பாலம் வழியாகத் திருப்பப்பட்டுள்ளது. +10 நிமிடம்.',
NOW(),TRUE,16);
