import json
import logging
import asyncio
from datetime import datetime, timezone
import paho.mqtt.client as mqtt
from app.core.config import settings
from app.models.telemetry import TelemetryRecord, AlertLog, Device
from app.services.fcm_notifier import fcm_notifier
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select

logger = logging.getLogger(__name__)

class MQTTSubscriberService:
    def __init__(self):
        self.client = mqtt.Client(client_id="smartgas_backend_service")
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message
        self.client.on_disconnect = self._on_disconnect
        self.engine = create_async_engine(settings.DATABASE_URL, echo=False)
        self.async_session = sessionmaker(self.engine, class_=AsyncSession, expire_on_commit=False)
        self._loop = None

    def start(self, loop: asyncio.AbstractEventLoop):
        self._loop = loop
        try:
            logger.info(f"[MQTT] Connexion au broker {settings.MQTT_BROKER_HOST}:{settings.MQTT_BROKER_PORT}...")
            self.client.connect_async(settings.MQTT_BROKER_HOST, settings.MQTT_BROKER_PORT, settings.MQTT_KEEP_ALIVE)
            self.client.loop_start()
        except Exception as e:
            logger.error(f"[MQTT] Erreur connexion initiale au broker: {e}")

    def stop(self):
        self.client.loop_stop()
        self.client.disconnect()
        logger.info("[MQTT] Service MQTT arrêté.")

    def _on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            logger.info("[MQTT] Connecté avec succès au broker Mosquitto.")
            client.subscribe("smartgas/+/telemetry")
            client.subscribe("smartgas/+/events")
            client.subscribe("smartgas/+/status")
            logger.info("[MQTT] Abonnements actifs : telemetry, events, status")
        else:
            logger.error(f"[MQTT] Échec connexion code: {rc}")

    def _on_disconnect(self, client, userdata, rc):
        logger.warning(f"[MQTT] Déconnexion broker code: {rc}. Reconnexion automatique...")

    def _on_message(self, client, userdata, msg):
        try:
            topic = msg.topic
            payload = json.loads(msg.payload.decode("utf-8"))
            parts = topic.split("/")
            if len(parts) < 3:
                return
            device_id = parts[1]
            sub_type = parts[2]

            if self._loop and self._loop.is_running():
                asyncio.run_coroutine_threadsafe(
                    self._process_message(device_id, sub_type, payload),
                    self._loop
                )
        except Exception as e:
            logger.error(f"[MQTT] Erreur traitement message sur {msg.topic}: {e}")

    async def _process_message(self, device_id: str, sub_type: str, data: dict):
        async with self.async_session() as session:
            try:
                # Vérifier / créer l'appareil en base
                stmt = select(Device).where(Device.id == device_id)
                res = await session.execute(stmt)
                device = res.scalar_one_or_none()
                if not device:
                    device = Device(id=device_id, name=f"SmartGas {device_id[-4:]}", is_online=True)
                    session.add(device)

                device.last_seen = datetime.now(timezone.utc)

                if sub_type == "status":
                    device.is_online = data.get("online", True)
                    await session.commit()

                elif sub_type == "telemetry":
                    rec = TelemetryRecord(
                        device_id=device_id,
                        weight_kg=data.get("weight_kg", 0.0),
                        gross_weight_kg=data.get("gross_weight_kg", 0.0),
                        level_percent=data.get("level_percent", 0.0),
                        gas_ppm=data.get("gas_ppm", 0),
                        leak=data.get("leak", False),
                        temperature_c=data.get("temperature_c"),
                        valve_state=data.get("valve_state", "OPEN"),
                        timestamp=data.get("timestamp", int(datetime.now(timezone.utc).timestamp()))
                    )
                    session.add(rec)
                    await session.commit()

                elif sub_type == "events":
                    ev_type = data.get("event", "unknown")
                    sev = data.get("severity", "INFO")
                    d_obj = data.get("data", {})
                    msg = d_obj.get("message", "Événement inconnu")

                    alert = AlertLog(
                        device_id=device_id,
                        event_type=ev_type,
                        severity=sev,
                        message=msg,
                        timestamp=data.get("timestamp", int(datetime.now(timezone.utc).timestamp()))
                    )
                    session.add(alert)
                    await session.commit()

                    if ev_type == "leak_critical":
                        ppm = int(d_obj.get("gas_ppm", 800))
                        thresh = int(d_obj.get("threshold_ppm", 400))
                        await fcm_notifier.send_leak_alert(device_id, ppm, thresh)

            except Exception as e:
                await session.rollback()
                logger.error(f"[DB] Erreur écriture télémétrie: {e}")

    def publish_command(self, device_id: str, action: str):
        topic = f"smartgas/{device_id}/cmd/action"
        payload = json.dumps({"action": action})
        self.client.publish(topic, payload, qos=1)
        logger.info(f"[MQTT] Commande envoyée sur {topic}: {payload}")

mqtt_service = MQTTSubscriberService()
