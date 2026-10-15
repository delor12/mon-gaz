from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import List, Optional
from datetime import datetime, timezone

from app.models.telemetry import TelemetryRecord, Device, AlertLog
from app.schemas.telemetry import (
    TelemetryData, HistoryResponse, HistoryPoint, ValveControlRequest, PredictionResult
)
from app.services.mqtt_subscriber import mqtt_service
from app.services.ml_predictor import ml_predictor
from app.core.config import settings

router = APIRouter()

# Dépendance d'injection de session DB
async def get_db():
    async with mqtt_service.async_session() as session:
        yield session

@router.get("/data", response_model=TelemetryData)
@router.get("/devices/{device_id}/data", response_model=TelemetryData)
async def get_latest_telemetry(device_id: str = "ESP32-SMARTGAS-8A4F", db: AsyncSession = Depends(get_db)):
    """Récupère le dernier enregistrement télémétrique du dispositif."""
    stmt = (
        select(TelemetryRecord)
        .where(TelemetryRecord.device_id == device_id)
        .order_by(desc(TelemetryRecord.timestamp))
        .limit(1)
    )
    res = await db.execute(stmt)
    rec = res.scalar_one_or_none()
    if not rec:
        # Données par défaut si aucune donnée enregistrée
        return TelemetryData(
            device_id=device_id,
            weight_kg=8.42,
            gross_weight_kg=21.42,
            level_percent=67.36,
            gas_ppm=145,
            leak=False,
            temperature_c=21.8,
            humidity_percent=48.5,
            valve_state="OPEN",
            buzzer_muted=False,
            sensor_fault=False,
            rssi=-64,
            uptime_s=86420,
            firmware="1.0.0",
            timestamp=int(datetime.now(timezone.utc).timestamp())
        )

    return TelemetryData(
        device_id=rec.device_id,
        weight_kg=rec.weight_kg,
        gross_weight_kg=rec.gross_weight_kg,
        level_percent=rec.level_percent,
        gas_ppm=rec.gas_ppm,
        leak=rec.leak,
        temperature_c=rec.temperature_c or 20.0,
        humidity_percent=rec.humidity_percent or 50.0,
        valve_state=rec.valve_state,
        buzzer_muted=False,
        sensor_fault=False,
        rssi=rec.rssi or -60,
        uptime_s=0,
        firmware="1.0.0",
        timestamp=rec.timestamp
    )

@router.get("/history", response_model=HistoryResponse)
@router.get("/devices/{device_id}/history", response_model=HistoryResponse)
async def get_history(
    device_id: str = "ESP32-SMARTGAS-8A4F",
    range: str = Query("day", regex="^(day|week|month)$"),
    resolution: str = Query("hour", regex="^(minute|hour|day)$"),
    db: AsyncSession = Depends(get_db)
):
    """Récupère l'historique de consommation pour affichage des graphiques."""
    stmt = (
        select(TelemetryRecord)
        .where(TelemetryRecord.device_id == device_id)
        .order_by(desc(TelemetryRecord.timestamp))
        .limit(100)
    )
    res = await db.execute(stmt)
    records = list(reversed(res.scalars().all()))

    points: List[HistoryPoint] = []
    if records:
        prev_w = records[0].weight_kg
        for r in records:
            conso = max(0.0, prev_w - r.weight_kg)
            prev_w = r.weight_kg
            points.append(HistoryPoint(
                timestamp=r.timestamp,
                weight_kg=r.weight_kg,
                consumption_kg=round(conso, 3)
            ))
    else:
        # Points de démonstration synthétiques si la base est neuve
        now = int(datetime.now(timezone.utc).timestamp())
        base_w = 8.54
        for i in range(12, 0, -1):
            points.append(HistoryPoint(
                timestamp=now - (i * 3600),
                weight_kg=round(base_w - (0.02 * (12 - i)), 3),
                consumption_kg=0.02
            ))

    return HistoryResponse(
        range=range,
        resolution=resolution,
        count=len(points),
        points=points
    )

@router.post("/devices/{device_id}/valve/control")
async def control_valve(
    device_id: str,
    payload: ValveControlRequest,
    db: AsyncSession = Depends(get_db)
):
    """Envoie la commande d'ouverture ou de fermeture de vanne via MQTT."""
    # Vérifier si fuite active
    stmt = (
        select(TelemetryRecord)
        .where(TelemetryRecord.device_id == device_id)
        .order_by(desc(TelemetryRecord.timestamp))
        .limit(1)
    )
    res = await db.execute(stmt)
    rec = res.scalar_one_or_none()

    if rec and rec.leak and payload.action == "OPEN":
        raise HTTPException(
            status_code=403,
            detail={
                "code": "LEAK_ACTIVE_VALVE_LOCKED",
                "message": "Action refusée : Impossible d'ouvrir la vanne pendant une fuite de gaz active."
            }
        )

    mqtt_service.publish_command(device_id, f"VALVE_{payload.action}")
    return {"valve_state": payload.action, "sent": True}

@router.post("/devices/{device_id}/alarm/mute")
async def mute_alarm(device_id: str):
    """Transmet la commande de sourdine du buzzer à l'ESP32."""
    mqtt_service.publish_command(device_id, "MUTE")
    return {"muted": True, "duration_seconds": 120}

@router.get("/devices/{device_id}/prediction", response_model=PredictionResult)
async def get_prediction(device_id: str, db: AsyncSession = Depends(get_db)):
    """Calcule l'autonomie restante et détecte les anomalies par IA."""
    # Récupérer l'appareil pour avoir sa capacité
    stmt_dev = select(Device).where(Device.id == device_id)
    res_dev = await db.execute(stmt_dev)
    device = res_dev.scalar_one_or_none()
    capacity = device.capacity_kg if device else 12.5

    # Récupérer l'historique récent
    stmt_hist = (
        select(TelemetryRecord.timestamp, TelemetryRecord.weight_kg)
        .where(TelemetryRecord.device_id == device_id)
        .order_by(TelemetryRecord.timestamp.asc())
        .limit(500)
    )
    res_hist = await db.execute(stmt_hist)
    history = res_hist.all()

    # Dernier état
    stmt_last = (
        select(TelemetryRecord)
        .where(TelemetryRecord.device_id == device_id)
        .order_by(desc(TelemetryRecord.timestamp))
        .limit(1)
    )
    res_last = await db.execute(stmt_last)
    last = res_last.scalar_one_or_none()

    current_w = last.weight_kg if last else 8.42
    current_lvl = last.level_percent if last else 67.3

    return ml_predictor.predict(
        device_id=device_id,
        current_weight_kg=current_w,
        current_level_percent=current_lvl,
        capacity_kg=capacity,
        history_points=[(h[0], h[1]) for h in history]
    )
