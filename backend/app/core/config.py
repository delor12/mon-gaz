from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    PROJECT_NAME: str = "SmartGas Backend & Telemetry Service"
    API_V1_STR: str = "/api/v1"
    
    # Base de données (SQLite par défaut en dev local / PostgreSQL en production)
    DATABASE_URL: str = "sqlite+aiosqlite:///./smartgas.db"
    SYNC_DATABASE_URL: str = "sqlite:///./smartgas.db"
    
    # Broker MQTT
    MQTT_BROKER_HOST: str = "localhost"
    MQTT_BROKER_PORT: int = 1883
    MQTT_TLS_PORT: int = 8883
    MQTT_KEEP_ALIVE: int = 60
    
    # Sécurité & JWT
    JWT_SECRET: str = "sg_jwt_secret_super_secure_key_change_in_production_2026"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 jours
    
    # CORS
    CORS_ORIGINS: str = "*"
    
    # Notifications Push Firebase
    FCM_SERVER_KEY: str = ""
    FCM_CREDENTIALS_PATH: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
