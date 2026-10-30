from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload
from .models import Stop, BusRoute, RouteStop, Bus, User, PassengerReport, StopCorrection, Diversion, FareRule

STOPS = [
(1,"Broadway","பிராட்வே",13.0900,80.2860,1,9),
(2,"Chennai Central","சென்னை சென்ட்ரல்",13.0827,80.2755,1,12),
(3,"Anna Salai","அண்ணா சாலை",13.0620,80.2680,1,7),
(4,"T. Nagar","தி. நகர்",13.0418,80.2341,1,10),
(5,"Guindy","கிண்டி",13.0067,80.2206,1,11),
(6,"Chromepet","குரோம்பேட்டை",12.9516,80.1462,1,8),
(7,"Tambaram","தாம்பரம்",12.9249,80.1000,1,14),
(8,"Perungalathur","பெருங்களத்தூர்",12.9034,80.0905,1,6),
(9,"Vandalur","வண்டலூர்",12.8918,80.0810,1,7),
(10,"Guduvanchery","கூடுவாஞ்சேரி",12.8452,80.0605,1,6),
(11,"Potheri","பொத்தேரி",12.8230,80.0450,1,5),
(12,"SRM University","எஸ்.ஆர்.எம். பல்கலை",12.8230,80.0444,0,2),
(13,"Maraimalai Nagar","மறைமலை நகர்",12.7940,80.0250,1,8),
(14,"Chengalpattu","செங்கல்பட்டு",12.6819,79.9888,1,13),
(15,"Koyambedu (CMBT)","கோயம்பேடு (சி.எம்.பி.டி)",13.0694,80.1948,1,12),
(16,"Vadapalani","வடபழனி",13.0500,80.2121,1,6),
]
ROUTES = [
(1,"21G","#14213d","Broadway – Tambaram","05:00",15,"22:00",0,[(1,0),(2,8),(3,20),(4,38),(5,52),(6,78),(7,90)]),
(2,"M70","#2563eb","Tambaram – Chengalpattu (via SRM)","04:45",10,"23:00",0,[(7,0),(8,12),(9,22),(10,38),(11,50),(12,53),(13,65),(14,85)]),
(3,"119","#1f9d5b","Koyambedu – Chengalpattu","05:15",20,"21:30",1,[(15,0),(16,12),(5,28),(7,58),(9,72),(10,86),(11,96),(13,108),(14,125)]),
(4,"51B","#e08a1e","T. Nagar – Guduvanchery","05:30",12,"21:45",0,[(4,0),(5,14),(6,40),(7,52),(8,64),(9,74),(10,90)]),
(5,"T51","#8b5cf6","Guindy – SRM University","06:00",30,"20:30",0,[(5,0),(6,26),(7,38),(9,58),(10,74),(11,86),(12,89)]),
]
BUSES = [
("TN01-N-2101",1,.32,61),("TN01-N-2102",1,.78,24),("TN21-N-7010",2,.20,88),
("TN21-N-7011",2,.62,45),("TN21-N-1190",3,.45,30),("TN01-N-5151",4,.55,72),("TN21-N-0510",5,.40,38)
]
REPORTS = [(2,8,80,6),(2,12,60,14),(3,20,90,9),(3,15,55,22),(1,4,70,11),(4,6,50,30),(5,2,65,18)]

def seed_database(db: Session):
    if db.scalar(select(Stop.id).limit(1)) is not None:
        return
    for row in STOPS:
        db.add(Stop(id=row[0], name_en=row[1], name_ta=row[2], lat=row[3], lng=row[4], verified=bool(row[5]), confirmations=row[6]))
    for rid,no,color,name,first,freq,last,diverted,stops in ROUTES:
        route = BusRoute(id=rid, route_no=no, color=color, name=name, first_departure=first, frequency_min=freq, last_departure=last, diverted=bool(diverted))
        db.add(route)
        for seq,(sid,offset) in enumerate(stops, start=1):
            db.add(RouteStop(route_id=rid, stop_id=sid, sequence_no=seq, offset_min=offset))
    for bid,rid,progress,crowd in BUSES:
        db.add(Bus(id=bid, route_id=rid, progress=progress, crowd_percent=crowd))
    db.add(User(id=1, name="Demo Passenger", email="demo@busroute.local", trust_score=50))
    for rid,minutes,trust,ago in REPORTS:
        db.add(PassengerReport(route_id=rid, report_type="delay", minutes_late=minutes, user_trust=trust))
    db.add(StopCorrection(stop_id=12, note="Stop is at SRM Main Gate, not Potheri junction", votes=2, verified=False))
    db.add(Diversion(route_id=3, note_en="Diverted via Vadapalani flyover due to road work. Expect +10 min.", note_ta="சாலைப் பணி காரணமாக வடபழனி மேம்பாலம் வழியாகத் திருப்பப்பட்டுள்ளது. +10 நிமிடம்.", active=True))
    for cat,mul in [("general",1.0),("student",.5),("senior",.5),("woman",0.0)]:
        db.add(FareRule(category=cat,multiplier=mul))
    db.commit()
