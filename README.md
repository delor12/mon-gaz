# 🔥 SMART GAS (MonGaz) - Système Intelligent de Surveillance de Bouteille de Gaz GPL

[![CI Firmware](https://github.com/smartgas/smartgas/actions/workflows/ci-firmware.yml/badge.svg)](https://github.com/smartgas/smartgas/actions)
[![CI Mobile](https://github.com/smartgas/smartgas/actions/workflows/ci-mobile.yml/badge.svg)](https://github.com/smartgas/smartgas/actions)
[![CI Web](https://github.com/smartgas/smartgas/actions/workflows/ci-web.yml/badge.svg)](https://github.com/smartgas/smartgas/actions)
[![CI Backend](https://github.com/smartgas/smartgas/actions/workflows/ci-backend.yml/badge.svg)](https://github.com/smartgas/smartgas/actions)

Système embarqué IoT et distribué de monitoring continu pour bouteilles de gaz GPL (Butane / Propane) à destination des ménages et des professionnels.  
Un boîtier à base d'**ESP32** mesure en permanence la masse de gaz restante via une cellule de charge **HX711** et surveille les fuites par capteur **MQ-6** avec alarme locale autonome et coupure automatique par électrovanne. Une application **Flutter** (Android/iOS) et une application **React 18 PWA** affichent les métriques en temps réel, prédisent l'autonomie restante par IA et alertent l'utilisateur.

> **PRIORITÉ ABSOLUE : LA SÉCURITÉ**  
> Une fuite de gaz est signalée et coupée immédiatement par le matériel (Buzzer 85 dB, LED stroboscopique, coupure électrovanne), **même si le Wi-Fi, Internet, le téléphone ou les applications sont indisponibles**.

---

## 🏗️ Architecture "Local d'Abord, Cloud en Option"

```text
smartgas/
├── firmware/         # C++ PlatformIO ESP32 (FreeRTOS multi-tâches, LittleFS, TFT_eSPI)
├── mobile/           # Flutter (iOS & Android, Riverpod, go_router, fl_chart)
├── web/              # React 18, TypeScript, Vite, PWA installable, Tailwind CSS
├── backend/          # Optionnel : Mosquitto MQTT TLS, FastAPI, TimescaleDB, Docker Compose
├── shared/           # Tokens de design partagés (Bleu/Or), schémas et simulateur
├── docs/             # Documentation d'API OpenAPI, schéma de câblage, étalonnage, roadmap
└── README.md
```

```mermaid
flowchart TD
    subgraph Local["Réseau Local Résidentiel (100% Fonctionnel Hors-Ligne)"]
        ESP32["Boîtier ESP32 (SmartGas)\n• Tâche Capteurs (10Hz HX711 + MQ-6)\n• Tâche Sécurité Autonome (FreeRTOS Core 1)\n• Serveur Web REST + WebSocket"]
        TFT["Écran TFT 2.4\" + Buzzer 85dB\n+ LED Rouge + Électrovanne Gaz"]
        WebLocal["PWA Web Embarquée (LittleFS)\nhttp://smartgas.local"]
        AppLocal["App Mobile Flutter\n(Connexion directe WebSocket LAN)"]
        
        ESP32 -->|GPIO Direct (Indépendant du Wi-Fi)| TFT
        ESP32 <-->|mDNS / HTTP REST / WS| WebLocal
        ESP32 <-->|mDNS / HTTP REST / WS| AppLocal
    end

    subgraph Cloud["Cloud Distant (Optionnel)"]
        MQTT["Broker Mosquitto (MQTTS:8883 / WSS:9001)"]
        FastAPI["API Backend FastAPI + TimescaleDB"]
        FCM["Firebase Push Notifications (FCM)"]
        
        MQTT <--> FastAPI
        FastAPI --> FCM
    end

    subgraph RemoteUser["Utilisateur en Déplacement (4G/5G)"]
        AppRemote["App Mobile & Web Distante\n(MQTTS / API REST Cloud)"]
    end

    ESP32 -.->|MQTTS sur TLS (Optionnel)| MQTT
    FCM -.->|Push critique si fuite| AppRemote
    MQTT <-->|WSS / MQTTS| AppRemote
```

---

## 🎨 Charte Graphique : Bleu Profond & Or

Conçue pour un rendu premium, élégant et ergonomique :
- **Bleu Principal** `#0A2A6B` (fond, en-têtes) & **Bleu Profond** `#061A45` (surfaces, cartes)
- **Bleu Électrique** `#1E5EFF` (accents, graphiques)
- **Or** `#D4AF37` (jauge circulaire, bordures, icônes) & **Dégradé Or** `#F5D76E` $\rightarrow$ `#D4AF37`
- **Jaune Vif** `#FFD60A` (boutons d'action, avertissements)
- **Rouge Alerte** `#E5383B` (réservé exclusivement aux alertes critiques de fuite)
- **Texte** `#F5F7FA` sur fond sombre ; contraste certifié WCAG AA.

---

## 🚀 Guide de Démarrage et Lancement Pas à Pas

### Méthode A : Test Rapide en Mode Démo (Sans Matériel Requis)
Vous pouvez tester l'ensemble du système en moins de 30 secondes grâce au simulateur d'ESP32 inclus :

1. **Lancer le simulateur d'ESP32** (API REST + WebSocket 1 Hz) :
   ```bash
   pip install aiohttp
   python3 shared/demo/demo_simulator.py
   ```
2. **Lancer l'application Web React** :
   ```bash
   cd web
   npm install
   npm run dev
   ```
   👉 Ouvrez `http://localhost:3000`. L'interface se connecte immédiatement au simulateur !

3. **Lancer l'application Mobile Flutter** :
   ```bash
   cd mobile
   flutter pub get
   flutter run
   ```

---

### Méthode B : Déploiement sur le Prototype Matériel ESP32

#### 1. Matériel Nécessaire :
- 1 $\times$ ESP32-WROOM-32D
- 1 $\times$ Cellule de charge 40 kg/50 kg + Amplificateur HX711
- 1 $\times$ Capteur de gaz MQ-6 (ou MQ-2) branché sur GPIO 34 (ADC1)
- 1 $\times$ Capteur de température/humidité DHT22 (GPIO 32)
- 1 $\times$ Écran TFT SPI 240x320 ST7789 ou ILI9341
- 1 $\times$ Buzzer actif 5V (GPIO 25) + Transistor 2N2222
- 1 $\times$ LED d'alerte rouge (GPIO 26) + résistance 220 $\Omega$
- 1 $\times$ Module relais 5V (GPIO 27) + Électrovanne 12V NC gaz
- 1 $\times$ Bouton poussoir d'appairage (GPIO 33)

Consultez le schéma de câblage complet : [`docs/wiring_schematic.md`](file:///home/t-k-f-d-m/Documents/MonGaz/docs/wiring_schematic.md).

#### 2. Compilation et Téléversement du Firmware :
```bash
cd firmware
# Compiler et flasher le binaire via USB
pio run -e esp32dev --target upload

# Flasher les fichiers de l'interface Web dans la mémoire LittleFS
pio run -e esp32dev --target uploadfs

# Ouvrir la console série de diagnostic
pio device monitor -b 115200
```

Au démarrage, l'ESP32 tente de se connecter au Wi-Fi. S'il n'est pas configuré, il crée automatiquement le point d'accès Wi-Fi **`SmartGas-Setup`** (mot de passe : `smartgas123`). Connectez-vous dessus pour renseigner votre SSID résidentiel via le portail captif.

---

### Méthode C : Déploiement du Backend Cloud Optionnel
Pour activer la synchronisation distante et les notifications push :

```bash
cd backend
docker compose up -d
```
Les services suivants sont alors opérationnels :
- Broker Mosquitto MQTT/TLS : ports `1883`, `8883` et WebSocket `9001`
- Base de données TimescaleDB : port `5432`
- API FastAPI : `http://localhost:8000` (Documentation Swagger sur `/docs`)

---

## 🧪 Guide de Test et de Validation Pas à Pas

### Étape 1 : Validation Visuelle et Interface (Mode Démo)
1. Ouvrez l'application Mobile ou Web.
2. Activez le commutateur **"Mode Démo"** dans les Paramètres.
3. Testez les différents scénarios :
   - **Nominal** : Observez la jauge circulaire dorée animée se positionner à 67.3% (8.42 kg restant) et l'estimation d'autonomie ("12 j : 45 min").
   - **Niveau Bas** : La jauge passe en jaune à 11.6% et affiche une recommandation de réapprovisionnement.
   - **🚨 Fuite de Gaz** : L'écran bascule instantanément en alerte rouge stroboscopique, la sirène Web Audio retentit, l'électrovanne passe à l'état `FERMÉE` et les consignes de sécurité vitales apparaissent.

---

### Étape 2 : Étalonnage du Prototype Physique (Tare & Masse Étalon)
Consultez le guide détaillé : [`docs/calibration_guide.md`](file:///home/t-k-f-d-m/Documents/MonGaz/docs/calibration_guide.md).

1. **Tare du plateau** :
   - Assurez-vous que le plateau de pesée mécanique est totalement vide.
   - Appuyez sur **"Tare (0 kg)"** dans l'application. L'ESP32 enregistre l'offset dans sa mémoire flash NVS. L'écran TFT affiche `0.00 kg`.
2. **Calibration avec masse de référence** :
   - Déposez un poids connu (ex: **5.00 kg**) au centre du plateau.
   - Cliquez sur **"Étalonner"**, saisissez `5.0` et validez.
   - Le coefficient de conversion ticks/kg est calculé et persisté.

---

### Étape 3 : Scénario de Fuite Réelle Simulée en Toute Sécurité
Pour vérifier la chaîne de sécurité matérielle de bout en bout sans aucun danger :

1. Munissez-vous d'un **briquet à gaz ordinaire**.
2. **ATTENTION : N'ALLUMEZ PAS LA FLAMME**.
3. Pressez simplement la gâchette du briquet pour libérer un filet de gaz à 5 cm du capteur MQ-6 pendant 1 seconde.
4. **Vérifications instantanées (< 2 secondes)** :
   - ✅ **Buzzer local** : Tonalité stridente 2.7 kHz pulsée autonome (fonctionne même si la box Wi-Fi est débranchée).
   - ✅ **LED rouge** : Clignotement stroboscopique immédiat.
   - ✅ **Relais d'électrovanne** : Déclenchement audible sec (coupure de l'arrivée de gaz).
   - ✅ **Écran TFT** : Écran rouge clignotant `! DANGER ! FUITE DE GAZ`.
   - ✅ **Applications Web & Mobile** : Réception immédiate du paquet WebSocket `leak_critical` et affichage plein écran des consignes d'évacuation.
5. Éloignez le briquet et ventilez l'air autour du capteur. Dès que la concentration redescend sous 320 ppm (hystérésis), le système réarme automatiquement la surveillance.

---

## 🔒 Sécurité et Spécification de l'API

- **Contrat OpenAPI 3.0 unifié** : [`docs/openapi.yaml`](file:///home/t-k-f-d-m/Documents/MonGaz/docs/openapi.yaml)
- **Documentation complète de l'API & WebSocket** : [`docs/api.md`](file:///home/t-k-f-d-m/Documents/MonGaz/docs/api.md)
- **Appairage par Code PIN Physique** : Code aléatoire à 6 chiffres émis sur l'écran TFT physique validé par `POST /api/v1/auth/pair`.
- **Verrouillage Matériel Inviolable** : Toute requête HTTP ou MQTT tentant de forcer l'ouverture de l'électrovanne alors qu'une fuite est en cours est catégoriquement rejetée avec un code HTTP `403 LEAK_ACTIVE_VALVE_LOCKED`.

---

## 🔮 Feuille de Route Technologique (Roadmap V2.0)
Consultez le document dédié : [`docs/roadmap.md`](file:///home/t-k-f-d-m/Documents/MonGaz/docs/roadmap.md).
1. **Intégration Domotique Home Assistant** via MQTT Discovery automatique.
2. **Vanne Motorisée à Bille Bistable** ultra-basse consommation avec super-condensateur de secours.
3. **Capteur de Débit Massique Thermique / Ultrasonique** pour mesure instantanée en $L/\text{min}$.
4. **Support Assistants Vocaux** via Matter over Thread (ESP32-C6 / Apple HomeKit, Google Home, Alexa).
5. **Connectivité Cellulaire de Secours NB-IoT / LTE-M** pour zones isolées.

---

## 👥 Auteur et Licence
Projet conçu par l'équipe **SmartGas Architecture & Embedded Systems**.  
Code source sous licence MIT. Prêt pour la production et l'industrialisation.
