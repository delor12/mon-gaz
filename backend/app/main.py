import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.models.telemetry import Base
from app.services.mqtt_subscriber import mqtt_service
from app.api.v1.endpoints import telemetry, devices
from sqlalchemy.ext.asyncio import create_async_engine

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("smartgas")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Démarrage : création des tables et initialisation du client MQTT
    logger.info(f"Démarrage de {settings.PROJECT_NAME}...")
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Tables de base de données vérifiées/créées.")

    loop = asyncio.get_event_loop()
    mqtt_service.start(loop)
    yield
    # Arrêt propre
    mqtt_service.stop()
    await engine.dispose()
    logger.info("Arrêt du backend SmartGas terminé.")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description="Backend Cloud & Local pour le système de monitoring GPL SmartGas",
    lifespan=lifespan
)

# Configuration CORS
origins = ["*"] if settings.CORS_ORIGINS == "*" else settings.CORS_ORIGINS.split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclusion des routeurs
app.include_router(telemetry.router, prefix=settings.API_V1_STR, tags=["Télémétrie & Contrôle"])
app.include_router(devices.router, prefix=settings.API_V1_STR, tags=["Gestion des Appareils"])

@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "mqtt_connected": mqtt_service.client.is_connected()
    }
