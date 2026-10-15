# Contrat d'API SmartGas (REST, WebSocket, MQTT)

Document de référence unifié pour l'ESP32, l'application Mobile (Flutter), l'application Web (React/PWA) et le Backend FastAPI.

---

## 1. Découverte du Dispositif (Device Discovery)

L'application doit pouvoir trouver le boîtier SmartGas sur le réseau local sans que l'utilisateur ait à connaître son IP :

1. **mDNS (Multicast DNS - Recommandé)** :
   - Nom d'hôte publié : `smartgas.local` ou `smartgas-<device_id>.local` (ex: `smartgas-8a4f.local`)
   - Service mDNS : `_smartgas._tcp.local.` sur le port `80`
   - Enregistrement TXT : `id=ESP32-SMARTGAS-8A4F`, `fw=1.0.0`, `model=SG-V1`
2. **Scan de sous-réseau UDP Broadcast (Fallback 1)** :
   - L'application envoie un paquet UDP sur le port `8266` avec le payload ASCII : `"SMARTGAS_DISCOVER"`.
   - L'ESP32 répond avec un JSON : `{"device_id":"ESP32-SMARTGAS-8A4F","ip":"192.168.1.50","port":80}`.
3. **Saisie Manuelle d'IP (Fallback 2)** :
   - Champ de saisie dans l'application avec bouton "Tester la connexion" appelant `GET /api/v1/system/info`.

---

## 2. Authentification et Sécurité des Échanges

### 2.1. Protocole d'Appairage par Code PIN Écran TFT
1. Lors du premier démarrage ou lors de l'appui long sur le bouton physique "Pair", l'écran TFT affiche :
   ```text
   +------------------------------+
   |        SMART GAS V1.0        |
   |                              |
   |      CODE D'APPAIRAGE :      |
   |           [ 482 910 ]        |
   |                              |
   |  Valable encore : 180 s      |
   +------------------------------+
   ```
2. L'application mobile ou web envoie :
   ```http
   POST /api/v1/auth/pair HTTP/1.1
   Host: smartgas.local
   Content-Type: application/json

   {
     "pin_code": "482910",
     "client_name": "iPhone 15 Pro - Kevin"
   }
   ```
3. L'ESP32 valide le code à 6 chiffres. S'il est valide :
   ```http
   HTTP/1.1 200 OK
   Content-Type: application/json

   {
     "token": "sg_sec_9f81a7b3c2d4e5f601a2b3c4d5e6f7a8",
     "device_id": "ESP32-SMARTGAS-8A4F",
     "expires_in_days": 365
   }
   ```
4. **Sécurité contre les attaques Brute-Force** : Après 3 tentatives incorrectes, l'ESP32 bloque les requêtes de pairing pendant 5 minutes (`HTTP 429 Too Many Requests`).

### 2.2. En-têtes Requis pour les Actions d'Écriture
Toutes les requêtes de modification (`POST /api/v1/tare`, `POST /api/v1/calibrate`, `PUT /api/v1/config`, `POST /api/v1/valve/control`) nécessitent :
```http
Authorization: Bearer sg_sec_9f81a7b3c2d4e5f601a2b3c4d5e6f7a8
```
Les requêtes de lecture (`GET /api/v1/data`, `GET /api/v1/config`, `/ws`) sont publiques sur le LAN afin de garantir la fluidité des dashboards locaux.

### 2.3. Politique CORS Strict
L'ESP32 renvoie sur toutes ses routes HTTP :
```http
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

---

## 3. Endpoints REST v1

### 3.1. `GET /api/v1/data` - Télémétrie Instantanée
Retourne les données courantes filtrées et validées.

**Exemple de Requête :**
```bash
curl -X GET http://smartgas.local/api/v1/data
```

**Réponse `200 OK` :**
```json
{
  "device_id": "ESP32-SMARTGAS-8A4F",
  "weight_kg": 8.420,
  "gross_weight_kg": 21.420,
  "level_percent": 67.36,
  "gas_ppm": 145,
  "leak": false,
  "temperature_c": 21.8,
  "humidity_percent": 48.5,
  "valve_state": "OPEN",
  "buzzer_muted": false,
  "sensor_fault": false,
  "rssi": -64,
  "uptime_s": 86420,
  "firmware": "1.0.0",
  "timestamp": 1792004400
}
```

---

### 3.2. `GET /api/v1/history` - Historique de Masse et Consommation
Permet de tracer les courbes d'évolution du niveau et de calculer les moyennes.

**Paramètres Query :**
- `range` : `day` (défaut), `week`, `month`
- `resolution` : `minute`, `hour` (défaut), `day`

**Exemple de Requête :**
```bash
curl -X GET "http://smartgas.local/api/v1/history?range=day&resolution=hour"
```

**Réponse `200 OK` :**
```json
{
  "range": "day",
  "resolution": "hour",
  "count": 4,
  "points": [
    { "timestamp": 1791993600, "weight_kg": 8.540, "consumption_kg": 0.000 },
    { "timestamp": 1791997200, "weight_kg": 8.520, "consumption_kg": 0.020 },
    { "timestamp": 1792000800, "weight_kg": 8.480, "consumption_kg": 0.040 },
    { "timestamp": 1792004400, "weight_kg": 8.420, "consumption_kg": 0.060 }
  ]
}
```

---

### 3.3. `POST /api/v1/tare` - Remise à Zéro du Plateau
Met à zéro l'offset du HX711 sans charge sur le plateau.

**Exemple de Requête :**
```bash
curl -X POST http://smartgas.local/api/v1/tare \
  -H "Authorization: Bearer <TOKEN>"
```

**Réponse `200 OK` :**
```json
{
  "success": true,
  "tare_offset": 8432190,
  "message": "Plateau taré à 0.000 kg avec succès."
}
```

---

### 3.4. `POST /api/v1/calibrate` - Calibration avec Masse Étalon
Calcule le coefficient d'échelle : $\text{scale} = \frac{\text{raw} - \text{offset}}{\text{known\_weight}}$.

**Exemple de Requête :**
```bash
curl -X POST http://smartgas.local/api/v1/calibrate \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"known_weight_kg": 5.0}'
```

**Réponse `200 OK` :**
```json
{
  "success": true,
  "calibration_factor": -22450.5,
  "measured_weight_kg": 5.002
}
```

---

### 3.5. `GET /api/v1/config` & `PUT /api/v1/config` - Configuration
Permet de modifier le type de bouteille (6 kg, 12.5 kg, 35 kg ou Custom), les seuils d'alerte, et le comportement des périphériques de sécurité.

**Exemple de Requête PUT :**
```bash
curl -X PUT http://smartgas.local/api/v1/config \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "bottle_type": "B12_5",
    "bottle_name": "Bouteille Gazinière",
    "capacity_kg": 12.5,
    "tare_weight_kg": 13.0,
    "leak_threshold_ppm": 400,
    "low_level_threshold_percent": 15.0,
    "critical_level_threshold_percent": 5.0,
    "buzzer_enabled": true,
    "valve_enabled": true,
    "valve_auto_cutoff": true,
    "mqtt_enabled": false,
    "mqtt_broker": "broker.smartgas.io",
    "mqtt_port": 8883
  }'
```

**Réponse `200 OK` :**
```json
{
  "success": true,
  "updated_config": {
    "bottle_type": "B12_5",
    "bottle_name": "Bouteille Gazinière",
    "capacity_kg": 12.5,
    "tare_weight_kg": 13.0,
    "leak_threshold_ppm": 400,
    "low_level_threshold_percent": 15.0,
    "critical_level_threshold_percent": 5.0,
    "buzzer_enabled": true,
    "valve_enabled": true,
    "valve_auto_cutoff": true,
    "mqtt_enabled": false,
    "mqtt_broker": "broker.smartgas.io",
    "mqtt_port": 8883
  }
}
```

---

### 3.6. `POST /api/v1/alarm/mute` - Mute Temporaire du Buzzer
Permet d'éteindre le buzzer local pendant une durée paramétrable (ex: 120s) pour éviter l'agression sonore pendant que l'utilisateur aère et intervient sur la bouteille.

```json
{
  "muted": true,
  "mute_remaining_seconds": 120
}
```

---

### 3.7. `POST /api/v1/valve/control` - Pilotage Électrovanne
Permet de couper manuellement l'arrivée de gaz depuis l'application.

```bash
curl -X POST http://smartgas.local/api/v1/valve/control \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"action": "CLOSE"}'
```

> **Verrouillage de Sécurité Immuable** : Si le système détecte `leak == true`, toute tentative d'envoi de `{"action": "OPEN"}` est immédiatement rejetée avec une erreur `403 Forbidden` (`LEAK_ACTIVE_VALVE_LOCKED`).

---

## 4. Flux WebSocket en Temps Réel (`/ws`)

L'ESP32 maintient un serveur WebSocket bidirectionnel sur le port 80 :
`ws://smartgas.local/ws` (ou `ws://<IP_ESP32>/ws`).

### 4.1. Télémétrie Périodique (1 Hz)
Chaque seconde, l'ESP32 diffuse à tous les clients connectés :
```json
{
  "type": "telemetry",
  "data": {
    "weight_kg": 8.420,
    "gross_weight_kg": 21.420,
    "level_percent": 67.36,
    "gas_ppm": 145,
    "leak": false,
    "temperature_c": 21.8,
    "valve_state": "OPEN",
    "buzzer_muted": false,
    "sensor_fault": false,
    "uptime_s": 86420,
    "timestamp": 1792004400
  }
}
```

### 4.2. Événements Asynchrones Instantanés
Dès qu'un événement survient (indépendamment du tick 1 Hz), un message immédiat est émis :

#### A. Alerte Critique Fuite de Gaz
```json
{
  "type": "event",
  "event": "leak_critical",
  "severity": "CRITICAL",
  "timestamp": 1792004412,
  "data": {
    "gas_ppm": 850,
    "threshold_ppm": 400,
    "valve_auto_closed": true,
    "message": "FUITE DE GAZ DÉTECTÉE ! Électrovanne fermée. Aérez immédiatement et fermez le robinet de la bouteille."
  }
}
```

#### B. Détection de Changement de Bouteille
Détecté automatiquement lorsqu'un saut soudain de masse positive $> 8\text{ kg}$ est observé :
```json
{
  "type": "event",
  "event": "bottle_replaced",
  "severity": "INFO",
  "timestamp": 1792004500,
  "data": {
    "previous_weight_kg": 0.450,
    "new_weight_kg": 12.600,
    "detected_delta_kg": 12.150,
    "message": "Nouvelle bouteille pleine détectée. Niveau réinitialisé à 100%."
  }
}
```

#### C. Anomalie / Panne Capteur
Si le HX711 ne répond pas sur `PD_SCK`/`DOUT` ou si la tension MQ est hors limites ($<0.1\text{V}$ ou $>4.9\text{V}$) :
```json
{
  "type": "event",
  "event": "sensor_fault",
  "severity": "WARNING",
  "timestamp": 1792004550,
  "data": {
    "sensor": "MQ_SENSOR",
    "state": "HEATING_OR_DISCONNECTED",
    "message": "Capteur de gaz en cours de préchauffage ou câble déconnecté."
  }
}
```

---

## 5. Contrat MQTT Cloud (Optionnel)

Lorsque le mode distant MQTT est activé dans la configuration de l'ESP32 :

- **Protocole** : MQTT v3.1.1 ou v5.0 sur TLS (Port `8883` avec certificat X.509 CA validé) ou WebSockets SSL (`wss://broker.smartgas.io:9001/mqtt`).
- **Arborescence des Topics** :
  - `smartgas/{device_id}/telemetry` (QoS 0, retain false, cadence 10s pour préserver la bande passante cellulaire).
  - `smartgas/{device_id}/events` (QoS 1, retain false, publication immédiate sur événement critique).
  - `smartgas/{device_id}/status` (QoS 1, retain true, LWT = Last Will and Testament `{"online": false}`).
  - `smartgas/{device_id}/cmd/config` (QoS 1, commande descendante envoyée par le Cloud).
  - `smartgas/{device_id}/cmd/action` (QoS 1, commande `MUTE_BUZZER`, `VALVE_CLOSE`, etc.).

---

## 6. Format Normalisé des Erreurs JSON

En cas d'erreur HTTP (4xx ou 5xx), le corps de la réponse suit scrupuleusement la structure :

```json
{
  "code": "CODE_ERREUR_STANDARD",
  "message": "Message explicatif lisible en français ou anglais",
  "details": {
    "champ": "Raison détaillée optionnelle"
  }
}
```

### Table des Codes d'Erreur :
| Code | HTTP | Signification |
| :--- | :--- | :--- |
| `INVALID_PIN_CODE` | 401 | Le code PIN d'appairage à 6 chiffres est erroné |
| `PAIRING_TIMEOUT` | 401 | La session d'appairage de 3 minutes a expiré |
| `UNAUTHORIZED` | 401 | Jeton Bearer manquant ou invalide |
| `TOO_MANY_REQUESTS` | 429 | Seuil de tentatives d'authentification dépassé |
| `INVALID_PARAM` | 400 | Paramètre de calibration ou configuration hors bornes |
| `LEAK_ACTIVE_VALVE_LOCKED` | 403 | Interdiction formelle d'ouvrir la vanne pendant une fuite |
| `SENSOR_UNAVAILABLE` | 503 | La cellule de pesée ou le capteur de gaz ne répond pas |
