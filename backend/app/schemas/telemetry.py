from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

class TelemetryData(BaseModel):
    device_id: str
    weight_kg: float
    gross_weight_kg: float
    level_percent: float
    gas_ppm: int
    leak: bool
    temperature_c: Optional[float] = 20.0
    humidity_percent: Optional[float] = 50.0
    valve_state: Optional[str] = "OPEN"
    buzzer_muted: Optional[bool] = False
    sensor_fault: Optional[bool] = False
    rssi: Optional[int] = -60
    uptime_s: Optional[int] = 0
    firmware: Optional[str] = "1.0.0"
    timestamp: int

class HistoryPoint(BaseModel):
    timestamp: int
    weight_kg: float
    consumption_kg: float

class HistoryResponse(BaseModel):
    range: str
    resolution: str
    count: int
    points: List[HistoryPoint]

class DeviceConfig(BaseModel):
    bottle_type: str = "B12_5"
    bottle_name: str = "Cuisine Principale"
    capacity_kg: float = 12.5
    tare_weight_kg: float = 13.0
    leak_threshold_ppm: int = 400
    low_level_threshold_percent: float = 15.0
    critical_level_threshold_percent: float = 5.0
    buzzer_enabled: bool = True
    valve_enabled: bool = False
    valve_auto_cutoff: bool = True
    mqtt_enabled: bool = True
    mqtt_broker: str = "broker.smartgas.io"
    mqtt_port: int = 8883

class DeviceOut(BaseModel):
    id: str
    name: str
    bottle_type: str
    capacity_kg: float
    tare_weight_kg: float
    is_online: bool
    last_seen: Optional[datetime] = None

    class Config:
        from_attributes = True

class ValveControlRequest(BaseModel):
    action: str = Field(..., pattern="^(OPEN|CLOSE)$")

class AlertEvent(BaseModel):
    id: int
    device_id: str
    event_type: str
    severity: str
    message: str
    timestamp: int
    acknowledged: bool

    class Config:
        from_attributes = True

class PredictionResult(BaseModel):
    device_id: str
    current_weight_kg: float
    current_level_percent: float
    days_remaining: int
    hours_remaining: int
    display_str: str = "12 j : 45 min"
    estimated_empty_date: str
    average_daily_consumption_kg: float
    confidence_interval_hours: int
    slow_leak_detected: bool
    recommendation: str

class UserCreate(BaseModel):
    email: str
    password: str
    full_name: Optional[str] = None

class UserOut(BaseModel):
    id: int
    email: str
    full_name: Optional[str] = None
    role: str

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
