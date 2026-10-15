from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, Integer, Boolean, DateTime, ForeignKey, Index
from sqlalchemy.orm import declarative_base, relationship

Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(100), nullable=True)
    role = Column(String(20), default="ADMIN") # "ADMIN" ou "VIEWER"
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    devices = relationship("Device", back_populates="owner")

class Device(Base):
    __tablename__ = "devices"

    id = Column(String(64), primary_key=True) # Ex: "ESP32-SMARTGAS-8A4F"
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    name = Column(String(100), default="Cuisine Principale")
    bottle_type = Column(String(20), default="B12_5")
    capacity_kg = Column(Float, default=12.5)
    tare_weight_kg = Column(Float, default=13.0)
    leak_threshold_ppm = Column(Integer, default=400)
    low_level_percent = Column(Float, default=15.0)
    critical_level_percent = Column(Float, default=5.0)
    is_online = Column(Boolean, default=False)
    last_seen = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    owner = relationship("User", back_populates="devices")
    telemetry_records = relationship("TelemetryRecord", back_populates="device", cascade="all, delete-orphan")
    alerts = relationship("AlertLog", back_populates="device", cascade="all, delete-orphan")

class TelemetryRecord(Base):
    __tablename__ = "telemetry_records"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(String(64), ForeignKey("devices.id"), nullable=False, index=True)
    weight_kg = Column(Float, nullable=False)
    gross_weight_kg = Column(Float, nullable=False)
    level_percent = Column(Float, nullable=False)
    gas_ppm = Column(Integer, nullable=False)
    leak = Column(Boolean, default=False, nullable=False)
    temperature_c = Column(Float, nullable=True)
    humidity_percent = Column(Float, nullable=True)
    valve_state = Column(String(20), default="OPEN")
    rssi = Column(Integer, nullable=True)
    timestamp = Column(Integer, nullable=False, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    device = relationship("Device", back_populates="telemetry_records")

    __table_args__ = (
        Index("idx_device_timestamp", "device_id", "timestamp"),
    )

class AlertLog(Base):
    __tablename__ = "alert_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(String(64), ForeignKey("devices.id"), nullable=False, index=True)
    event_type = Column(String(50), nullable=False) # "leak_critical", "level_low", "sensor_fault"
    severity = Column(String(20), nullable=False)   # "CRITICAL", "WARNING", "INFO"
    message = Column(String(255), nullable=False)
    timestamp = Column(Integer, nullable=False)
    acknowledged = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    device = relationship("Device", back_populates="alerts")
