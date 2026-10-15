from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from app.models.telemetry import Device
from app.schemas.telemetry import DeviceOut, DeviceConfig
from app.services.mqtt_subscriber import mqtt_service

router = APIRouter()

async def get_db():
    async with mqtt_service.async_session() as session:
        yield session

@router.get("/devices", response_model=List[DeviceOut])
async def list_devices(db: AsyncSession = Depends(get_db)):
    """Liste tous les boîtiers SmartGas enregistrés."""
    stmt = select(Device)
    res = await db.execute(stmt)
    return res.scalars().all()

@router.get("/devices/{device_id}", response_model=DeviceOut)
async def get_device(device_id: str, db: AsyncSession = Depends(get_db)):
    """Détails d'un boîtier spécifique."""
    stmt = select(Device).where(Device.id == device_id)
    res = await db.execute(stmt)
    dev = res.scalar_one_or_none()
    if not dev:
        raise HTTPException(status_code=404, detail="Dispositif non trouvé")
    return dev
