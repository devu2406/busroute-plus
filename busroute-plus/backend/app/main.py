from fastapi.middleware.cors import CORSMiddleware  # type: ignore[reportMissingImports]
from datetime import datetime, timedelta
from statistics import mean, pstdev
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException, Query  # type: ignore[reportMissingImports]
from sqlalchemy import select, func
from sqlalchemy.orm import Session, selectinload

from .database import Base, engine, get_db, SessionLocal
from .models import Stop, BusRoute, RouteStop, Bus, User, PassengerReport, StopCorrection, Diversion, FareRule
from .schemas import ReportCreate, UserCreate
from .seed import seed_database

app = FastAPI(
    title="BusRoute+ API",
    description="Community-verified Tamil Nadu bus finder API for route search, maps, reports, fares and insights.",
    version="1.0.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5501",
        "http://localhost:5501",
        "http://127.0.0.1:5500",
        "http://localhost:5500",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# For local development. In production, restrict this to your actual frontend origin.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        seed_database(db)

def route_payload(db: Session, route: BusRoute):
    stops = db.scalars(
        select(RouteStop).where(RouteStop.route_id == route.id).order_by(RouteStop.sequence_no)
    ).all()
    buses = db.scalars(select(Bus).where(Bus.route_id == route.id)).all()
    diversion = db.scalar(select(Diversion).where(Diversion.route_id == route.id, Diversion.active.is_(True)))
    return {
        "id": route.id,
        "no": route.route_no,
        "color": route.color,
        "name": route.name,
        "firstDep": route.first_departure,
        "freq": route.frequency_min,
        "lastDep": route.last_departure,
        "diverted": route.diverted or diversion is not None,
        "stops": [
            [rs.stop_id, rs.offset_min] for rs in stops
        ],
        "buses": [
            {"id": b.id, "routeId": b.route_id, "progress": b.progress, "crowd": b.crowd_percent}
            for b in buses
        ],
    }

def weighted_delay(db: Session, route_id: int) -> int:
    since = datetime.utcnow() - timedelta(hours=1)
    rows = db.execute(
        select(PassengerReport.minutes_late, PassengerReport.user_trust)
        .where(PassengerReport.route_id == route_id,
               PassengerReport.report_type == "delay",
               PassengerReport.created_at >= since)
    ).all()
    if not rows:
        # Use available historical reports if no recent reports exist.
        rows = db.execute(
            select(PassengerReport.minutes_late, PassengerReport.user_trust)
            .where(PassengerReport.route_id == route_id, PassengerReport.report_type == "delay")
        ).all()
    total_weight = sum(max(int(trust), 1) for _, trust in rows)
    return round(sum(minutes * max(int(trust), 1) for minutes, trust in rows) / total_weight) if total_weight else 0

def crowd_percent(db: Session, route_id: int) -> int:
    vals = db.scalars(select(Bus.crowd_percent).where(Bus.route_id == route_id)).all()
    return round(mean(vals)) if vals else 0

def to_minutes(value: str) -> int:
    h, m = map(int, value.split(":"))
    return h * 60 + m

def next_arrival(route: BusRoute, offset: int) -> Optional[int]:
    now = datetime.now()
    now_min = now.hour * 60 + now.minute
    dep = to_minutes(route.first_departure)
    last = to_minutes(route.last_departure)
    while dep <= last:
        if dep + offset >= now_min:
            return dep + offset
        dep += route.frequency_min
    return None

def fmt_minutes(value: Optional[int]) -> Optional[str]:
    if value is None:
        return None
    value = round(value) % 1440
    return f"{value // 60:02d}:{value % 60:02d}"

@app.get("/")
def root():
    return {"message": "BusRoute+ API is running", "docs": "/docs"}

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/api/stops")
def get_stops(db: Session = Depends(get_db)):
    stops = db.scalars(select(Stop).order_by(Stop.id)).all()
    return [{"id": s.id, "en": s.name_en, "ta": s.name_ta, "lat": s.lat, "lng": s.lng,
             "verified": int(s.verified), "conf": s.confirmations} for s in stops]

@app.get("/api/routes")
def get_routes(db: Session = Depends(get_db)):
    routes = db.scalars(select(BusRoute).order_by(BusRoute.id)).all()
    return [route_payload(db, r) for r in routes]

@app.get("/api/buses")
def get_buses(db: Session = Depends(get_db)):
    buses = db.scalars(select(Bus).order_by(Bus.id)).all()
    return [{"id": b.id, "routeId": b.route_id, "progress": b.progress, "crowd": b.crowd_percent} for b in buses]

@app.get("/api/routes/search")
def search_routes(
    from_text: str = Query(default="", alias="from"),
    to_text: str = Query(default="", alias="to"),
    route_text: str = Query(default="", alias="route"),
    db: Session = Depends(get_db),
):
    def matching_stop_ids(text: str):
        if not text.strip():
            return []
        q = f"%{text.strip().lower()}%"
        rows = db.scalars(select(Stop).where(func.lower(Stop.name_en).like(q) | Stop.name_ta.like(f"%{text.strip()}%"))).all()
        return {s.id for s in rows}

    from_ids, to_ids = matching_stop_ids(from_text), matching_stop_ids(to_text)
    routes = db.scalars(select(BusRoute).order_by(BusRoute.id)).all()
    out = []
    for route in routes:
        if route_text and route_text.lower() not in route.route_no.lower():
            continue
        seqs = db.scalars(select(RouteStop).where(RouteStop.route_id == route.id).order_by(RouteStop.sequence_no)).all()
        ids = [x.stop_id for x in seqs]
        if not from_ids and not to_ids:
            if route_text:
                fi, ti = 0, len(seqs) - 1
            else:
                continue
        else:
            fi = next((i for i, sid in enumerate(ids) if not from_ids or sid in from_ids), -1)
            ti = next((i for i, sid in enumerate(ids) if not to_ids or sid in to_ids), len(ids) - 1)
            if fi < 0 or ti < 0 or fi >= ti:
                continue
        from_rs, to_rs = seqs[fi], seqs[ti]
        delay = weighted_delay(db, route.id)
        arrival = next_arrival(route, from_rs.offset_min)
        crowd = crowd_percent(db, route.id)
        out.append({
            "route": route_payload(db, route),
            "fromId": from_rs.stop_id,
            "toId": to_rs.stop_id,
            "hops": ti - fi,
            "travel": to_rs.offset_min - from_rs.offset_min,
            "arrival": (arrival + delay) if arrival is not None else None,
            "arrivalFormatted": fmt_minutes((arrival + delay) if arrival is not None else None),
            "delay": delay,
            "crowd": crowd,
        })
    return sorted(out, key=lambda x: x["arrival"] if x["arrival"] is not None else 99999)

@app.get("/api/routes/{route_id}")
def get_route(route_id: int, db: Session = Depends(get_db)):
    route = db.get(BusRoute, route_id)
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")
    data = route_payload(db, route)
    data["delay"] = weighted_delay(db, route_id)
    data["crowd"] = crowd_percent(db, route_id)
    data["stopsDetailed"] = []
    for rs in db.scalars(select(RouteStop).where(RouteStop.route_id == route_id).order_by(RouteStop.sequence_no)).all():
        s = db.get(Stop, rs.stop_id)
        if s is None:
            continue
        data["stopsDetailed"].append({
            "id": s.id, "en": s.name_en, "ta": s.name_ta, "lat": s.lat, "lng": s.lng,
            "verified": s.verified, "conf": s.confirmations, "offset": rs.offset_min
        })
    return data

@app.get("/api/fares")
def get_fare(hops: int = Query(1, ge=1, le=100), category: str = "general", db: Session = Depends(get_db)):
    rule = db.scalar(select(FareRule).where(FareRule.category == category.lower()))
    if not rule:
        raise HTTPException(status_code=400, detail="Unknown passenger category")
    base_fare, per_stage = 5, 2
    amount = round((base_fare + per_stage * max(hops - 1, 0)) * rule.multiplier)
    return {"hops": hops, "category": category.lower(), "fare": amount, "currency": "INR"}

@app.post("/api/reports", status_code=201)
def submit_report(payload: ReportCreate, db: Session = Depends(get_db)):
    route = db.get(BusRoute, payload.route_id)
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")
    user = db.scalar(select(User).where(User.email == payload.email)) if payload.email else None
    if not user:
        user = db.get(User, 1)
    report = PassengerReport(
        route_id=payload.route_id, user_id=user.id if user else None,
        report_type=payload.report_type, minutes_late=payload.minutes_late,
        crowd_percent=payload.crowd_percent, stop_id=payload.stop_id,
        note=payload.note.strip(), user_trust=user.trust_score if user else 50
    )
    db.add(report)
    # Simple demo contribution score; production should use validation and anti-abuse checks.
    if user:
        user.trust_score = min(100, user.trust_score + 2)
    if payload.report_type == "crowd":
        buses = db.scalars(select(Bus).where(Bus.route_id == payload.route_id)).all()
        for bus in buses:
            bus.crowd_percent = payload.crowd_percent
    db.commit()
    db.refresh(report)
    return {"message": "Report saved", "report_id": report.id, "trust_score": user.trust_score if user else 50}

@app.post("/api/stops/{stop_id}/confirm")
def confirm_stop(stop_id: int, db: Session = Depends(get_db)):
    stop = db.get(Stop, stop_id)
    if not stop:
        raise HTTPException(status_code=404, detail="Stop not found")
    stop.confirmations += 1
    if stop.confirmations >= 3:
        stop.verified = True
    correction = db.scalar(select(StopCorrection).where(StopCorrection.stop_id == stop_id, StopCorrection.verified.is_(False)))
    if correction:
        correction.votes = stop.confirmations
        if stop.verified:
            correction.verified = True
    db.commit()
    return {"id": stop.id, "en": stop.name_en, "ta": stop.name_ta,
            "verified": stop.verified, "conf": stop.confirmations}

@app.get("/api/insights")
def get_insights(db: Session = Depends(get_db)):
    routes = db.scalars(select(BusRoute).order_by(BusRoute.id)).all()
    rows = []
    for route in routes:
        rows.append({
            "route": {"id": route.id, "no": route.route_no, "name": route.name, "color": route.color},
            "avg": weighted_delay(db, route.id),
            "n": db.scalar(select(func.count(PassengerReport.id)).where(PassengerReport.route_id == route.id)) or 0,
            "crowd": crowd_percent(db, route.id),
        })
    avg_values = [r["avg"] for r in rows]
    overall_mean = mean(avg_values) if avg_values else 0
    sd = pstdev(avg_values) if len(avg_values) > 1 else 0
    for row in rows:
        row["anomaly"] = bool(sd > 0 and row["avg"] > overall_mean + .8 * sd)
    rows.sort(key=lambda row: row["avg"])
    for i, row in enumerate(rows, start=1):
        row["rank"] = i
    stops = db.scalars(select(Stop)).all()
    buses_count = db.scalar(select(func.count(Bus.id))) or 0
    reports_count = db.scalar(select(func.count(PassengerReport.id))) or 0
    corrections = db.scalars(select(StopCorrection).where(StopCorrection.verified.is_(False))).all()
    return {
        "rows": rows,
        "mean": round(overall_mean, 1),
        "kpis": {
            "buses": buses_count, "routes": len(routes),
            "verifiedStops": sum(1 for s in stops if s.verified),
            "totalStops": len(stops), "reports": reports_count
        },
        "pendingCorrections": [
            {"stopId": c.stop_id, "note": c.note, "votes": c.votes, "needed": 3}
            for c in corrections
        ]
    }

@app.get("/api/diversions")
def get_diversions(db: Session = Depends(get_db)):
    rows = db.scalars(select(Diversion).where(Diversion.active.is_(True))).all()
    return [{"routeId": d.route_id, "note_en": d.note_en, "note_ta": d.note_ta} for d in rows]

@app.post("/api/users")
def create_demo_user(payload: UserCreate, db: Session = Depends(get_db)):
    existing = db.scalar(select(User).where(User.email == payload.email.lower()))
    if existing:
        raise HTTPException(status_code=409, detail="Email already exists")
    user = User(name=payload.name.strip(), email=payload.email.lower(), trust_score=50)
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"id": user.id, "name": user.name, "email": user.email, "trust_score": user.trust_score}

@app.get("/api/users/{user_id}")
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {"id": user.id, "name": user.name, "email": user.email, "trust_score": user.trust_score}
