from datetime import datetime
from sqlalchemy import String, Integer, Float, Boolean, DateTime, ForeignKey, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .database import Base

class Stop(Base):
    __tablename__ = "stops"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name_en: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    name_ta: Mapped[str] = mapped_column(String(160), nullable=False, default="")
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lng: Mapped[float] = mapped_column(Float, nullable=False)
    verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    confirmations: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

class BusRoute(Base):
    __tablename__ = "routes"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    route_no: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    color: Mapped[str] = mapped_column(String(20), default="#14213d")
    first_departure: Mapped[str] = mapped_column(String(5), default="05:00")
    frequency_min: Mapped[int] = mapped_column(Integer, default=15)
    last_departure: Mapped[str] = mapped_column(String(5), default="22:00")
    diverted: Mapped[bool] = mapped_column(Boolean, default=False)
    route_stops: Mapped[list["RouteStop"]] = relationship(back_populates="route", cascade="all, delete-orphan")
    buses: Mapped[list["Bus"]] = relationship(back_populates="route", cascade="all, delete-orphan")

class RouteStop(Base):
    __tablename__ = "route_stops"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    route_id: Mapped[int] = mapped_column(ForeignKey("routes.id"), index=True)
    stop_id: Mapped[int] = mapped_column(ForeignKey("stops.id"), index=True)
    sequence_no: Mapped[int] = mapped_column(Integer)
    offset_min: Mapped[int] = mapped_column(Integer, default=0)
    route: Mapped["BusRoute"] = relationship(back_populates="route_stops")
    stop: Mapped["Stop"] = relationship()
    __table_args__ = (UniqueConstraint("route_id", "sequence_no"),)

class Bus(Base):
    __tablename__ = "buses"
    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    route_id: Mapped[int] = mapped_column(ForeignKey("routes.id"), index=True)
    progress: Mapped[float] = mapped_column(Float, default=0.0)
    crowd_percent: Mapped[int] = mapped_column(Integer, default=0)
    route: Mapped["BusRoute"] = relationship(back_populates="buses")

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100), default="Demo Passenger")
    email: Mapped[str] = mapped_column(String(180), unique=True, index=True)
    trust_score: Mapped[int] = mapped_column(Integer, default=50)

class PassengerReport(Base):
    __tablename__ = "reports"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    route_id: Mapped[int] = mapped_column(ForeignKey("routes.id"), index=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    report_type: Mapped[str] = mapped_column(String(20), index=True)
    minutes_late: Mapped[int] = mapped_column(Integer, default=0)
    crowd_percent: Mapped[int] = mapped_column(Integer, default=0)
    stop_id: Mapped[int | None] = mapped_column(ForeignKey("stops.id"), nullable=True)
    note: Mapped[str] = mapped_column(Text, default="")
    user_trust: Mapped[int] = mapped_column(Integer, default=50)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

class StopCorrection(Base):
    __tablename__ = "stop_corrections"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    stop_id: Mapped[int] = mapped_column(ForeignKey("stops.id"), index=True)
    note: Mapped[str] = mapped_column(Text, nullable=False)
    votes: Mapped[int] = mapped_column(Integer, default=1)
    verified: Mapped[bool] = mapped_column(Boolean, default=False)

class Diversion(Base):
    __tablename__ = "diversions"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    route_id: Mapped[int] = mapped_column(ForeignKey("routes.id"), index=True)
    note_en: Mapped[str] = mapped_column(Text, default="")
    note_ta: Mapped[str] = mapped_column(Text, default="")
    active: Mapped[bool] = mapped_column(Boolean, default=True)

class FareRule(Base):
    __tablename__ = "fare_rules"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    category: Mapped[str] = mapped_column(String(30), unique=True)
    multiplier: Mapped[float] = mapped_column(Float, default=1.0)
