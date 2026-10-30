from pydantic import BaseModel, Field, EmailStr, ConfigDict
from typing import Literal

class ReportCreate(BaseModel):
    route_id: int
    report_type: Literal["delay", "crowd", "stop", "diversion"]
    minutes_late: int = Field(default=0, ge=0, le=240)
    crowd_percent: int = Field(default=0, ge=0, le=100)
    stop_id: int | None = None
    note: str = Field(default="", max_length=500)
    email: str | None = None

class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    email: str = Field(min_length=5, max_length=180)

class StopOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name_en: str
    name_ta: str
    lat: float
    lng: float
    verified: bool
    confirmations: int
