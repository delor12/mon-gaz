import logging
from typing import Optional
try:
    import firebase_admin
    from firebase_admin import messaging, credentials
    HAS_FIREBASE = True
except ImportError:
    HAS_FIREBASE = False

from app.core.config import settings

logger = logging.getLogger(__name__)

class FCMNotifier:
    def __init__(self):
        self._initialized = False
        if not HAS_FIREBASE:
            logger.info("[FCM] Mode journalisation locale actif (firebase-admin non installé).")
            return

        try:
            if settings.FCM_CREDENTIALS_PATH:
                cred = credentials.Certificate(settings.FCM_CREDENTIALS_PATH)
                firebase_admin.initialize_app(cred)
                self._initialized = True
                logger.info("[FCM] Firebase Admin initialisé avec succès.")
            else:
                logger.warning("[FCM] Aucune clé FCM configurée. Les notifications push seront journalisées uniquement.")
        except Exception as e:
            logger.error(f"[FCM] Erreur initialisation Firebase: {e}")

    async def send_leak_alert(self, device_id: str, gas_ppm: int, threshold_ppm: int):
        """Notification push prioritaire d'urgence absolue pour fuite de gaz."""
        title = "🚨 DANGER : FUITE DE GAZ DÉTECTÉE !"
        body = f"Fuite critique détectée ({gas_ppm} ppm > seuil {threshold_ppm} ppm). Électrovanne coupée. Fermez le robinet et aérez !"
        
        logger.critical(f"[PUSH ALARM] {title} - Dispositif {device_id} ({gas_ppm} ppm)")

        if not self._initialized:
            return

        message = messaging.Message(
            topic=f"device_{device_id}",
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="alarm_siren",
                    channel_id="smartgas_critical_leak",
                    color="#E5383B",
                    click_action="OPEN_ALERT_ACTIVITY"
                )
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="alarm_siren.wav",
                        content_available=True,
                        critical=True
                    )
                )
            ),
            data={
                "event": "leak_critical",
                "device_id": device_id,
                "gas_ppm": str(gas_ppm),
                "severity": "CRITICAL"
            }
        )

        try:
            response = messaging.send(message)
            logger.info(f"[FCM] Notification envoyée avec succès: {response}")
        except Exception as e:
            logger.error(f"[FCM] Erreur envoi notification critique: {e}")

    async def send_low_level_alert(self, device_id: str, level_pct: float):
        """Notification push niveau de gaz bas."""
        title = "⚠️ Niveau de gaz faible"
        body = f"Il reste seulement {level_pct:.1f}% de gaz dans votre bouteille. Pensez à commander une recharge."
        logger.warning(f"[PUSH WARN] {title} - Dispositif {device_id} ({level_pct}%)")

        if not self._initialized:
            return

        message = messaging.Message(
            topic=f"device_{device_id}",
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "event": "level_low",
                "device_id": device_id,
                "level_percent": str(level_pct)
            }
        )
        try:
            messaging.send(message)
        except Exception as e:
            logger.error(f"[FCM] Erreur envoi alerte niveau bas: {e}")

fcm_notifier = FCMNotifier()
