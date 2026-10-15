# Architecture Système - SmartGas (MonGaz)

## 1. Vision et Principes Directeurs

**SmartGas** est un système embarqué et distribué de surveillance intelligente de bouteilles de gaz GPL (Butane / Propane) pour les foyers et petites entreprises.

### Les 4 Piliers Fondamentaux :
1. **Sécurité Absolue & Autonome (Safety-First)** : Une fuite de gaz ou une anomalie thermique doit déclencher immédiatement les alarmes physiques locales (buzzer 85dB, LED stroboscopique rouge, fermeture électrovanne) **sans dépendance au réseau Wi-Fi, à Internet, au Cloud ou aux téléphones**.
2. **Local d'Abord (Local-First)** : L'application mobile et l'application web communiquent en priorité directement avec l'ESP32 sur le LAN (mDNS, REST HTTP/1.1, WebSockets). Le système fonctionne à 100% même en cas de coupure de la connexion Internet (Box déconnectée du WAN).
3. **Cloud en Option (Zero-Lock-in)** : Un backend optionnel (Mosquitto MQTT/TLS + FastAPI + PostgreSQL/TimescaleDB) permet le monitoring à distance hors du domicile et l'envoi de notifications Push Firebase (FCM).
4. **Précision & Intelligence Embarquée** : Filtrage numérique des mesures de masse (médiane mobile + Butterworth d'ordre 1), compensation de température, et prédiction d'autonomie à double palier (régression locale pondérée + modèle saisonnier/horaire).

---

## 2. Arborescence Complète du Projet

```text
smartgas/
├── .github/
│   └── workflows/
│       ├── ci-firmware.yml         # Compilation PlatformIO ESP32 & checks
│       ├── ci-mobile.yml           # Flutter analyze, test & build apk
│       ├── ci-web.yml              # Vite build, TypeScript typecheck, linter
│       └── ci-backend.yml          # Pytest, flake8, mypy, docker build
├── shared/                         # Contrats partagés (single source of truth)
│   ├── tokens/
│   │   └── theme.json              # Design tokens (couleurs, typographie, espacements)
│   └── schemas/
│       ├── telemetry.schema.json   # Schéma JSON strict pour REST/WebSocket/MQTT
│       ├── config.schema.json      # Schéma JSON de configuration
│       └── events.schema.json      # Schéma des événements asynchrones
├── docs/
│   ├── api.md                      # Spécification complète de l'API & WebSocket
│   ├── openapi.yaml                # Contrat OpenAPI 3.0.3 validé
│   ├── wiring_schematic.md         # Schéma de câblage complet ESP32, HX711, MQ, TFT, Relais
│   ├── calibration_guide.md        # Procédure de calibration pas à pas
│   └── architecture/
│       ├── overview.md             # Ce document
│       ├── adr-001-local-first.md
│       ├── adr-002-safety-freertos.md
│       ├── adr-003-web-mixed-content.md
│       └── adr-004-prediction-ai.md
├── firmware/                       # Firmware ESP32 (PlatformIO C++20)
│   ├── platformio.ini              # Config PlatformIO (ESP32-WROOM-32D, libs, partition table)
│   ├── partitions.csv              # Table de partition (OTA dual bank + LittleFS)
│   ├── include/
│   │   ├── config.h                # Pins GPIO, constantes, versions
│   │   ├── state.h                 # Structures de données partagées (Thread-safe FreeRTOS)
│   │   └── secrets.example.h       # Modèle de secrets Wi-Fi / MQTT
│   ├── src/
│   │   ├── main.cpp                # Point d'entrée, initialisation FreeRTOS & watchdog
│   │   ├── tasks/
│   │   │   ├── sensor_task.cpp     # Tâche FreeRTOS capteurs (HX711, MQ-6, DHT22) - 10Hz/1Hz
│   │   │   ├── alarm_task.cpp      # Tâche FreeRTOS sécurité prioritaire (Buzzer, Relais, LED)
│   │   │   ├── display_task.cpp    # Tâche FreeRTOS écran TFT (ST7789/ILI9341) - 5Hz
│   │   │   ├── network_task.cpp    # Tâche Wi-Fi, mDNS, WebServer, WebSocket
│   │   │   └── mqtt_task.cpp       # Tâche MQTT/TLS optionnelle avec buffer hors ligne
│   │   ├── services/
│   │   │   ├── weight_filter.cpp   # Filtre médian glissant + rejet des chocs
│   │   │   ├── gas_detector.cpp    # Détection fuite avec hystérésis & compensation T°C
│   │   │   ├── storage_manager.cpp # Gestion Preferences (NVS) & LittleFS
│   │   │   ├── captive_portal.cpp  # Portail captif pour configuration Wi-Fi initiale
│   │   │   └── ota_manager.cpp     # ArduinoOTA & rollback sécurisé
│   │   └── webserver/
│   │       ├── api_routes.cpp      # Contrôleurs endpoints REST v1
│   │       └── ws_handler.cpp      # Gestionnaire WebSocket (broadcast 1Hz + events)
│   └── data/                       # Fichiers LittleFS (Web UI PWA ultra-légère embarquée)
│       ├── index.html
│       ├── app.js
│       └── style.css
├── backend/                        # Backend optionnel Cloud / Serveur Local
│   ├── docker-compose.yml          # Mosquitto (TLS) + FastAPI + PostgreSQL/TimescaleDB
│   ├── mosquitto/
│   │   ├── config/mosquitto.conf   # Config broker, listeners 1883/8883/9001 (WSS)
│   │   └── certs/                  # Certificats SSL/TLS générés
│   ├── app/
│   │   ├── main.py                 # Application FastAPI (Uvicorn)
│   │   ├── core/
│   │   │   ├── config.py           # Pydantic Settings
│   │   │   └── security.py         # JWT tokens & API Keys
│   │   ├── models/
│   │   │   └── telemetry.py        # Modèles SQLAlchemy / SQLModel
│   │   ├── schemas/
│   │   │   └── telemetry.py        # Schémas Pydantic v2
│   │   ├── services/
│   │   │   ├── mqtt_subscriber.py  # Ingestion asynchrone des flux MQTT
│   │   │   ├── fcm_notifier.py     # Service Firebase Cloud Messaging pour alertes push
│   │   │   └── ml_predictor.py     # Service IA (scikit-learn / statsmodels EWMA)
│   │   └── api/
│   │       └── v1/
│   │           └── endpoints/      # Proxy REST miroir de l'ESP32 + agrégations
│   ├── Dockerfile
│   └── requirements.txt
├── mobile/                         # Application Mobile Flutter (iOS / Android)
│   ├── pubspec.yaml                # Dépendances (flutter_riverpod, dio, fl_chart, etc.)
│   ├── lib/
│   │   ├── main.dart               # Bootstrap Flutter & initialisation Riverpod
│   │   ├── app.dart                # MaterialApp.router, thème et internationalisation
│   │   ├── core/
│   │   │   ├── constants/          # Constantes, tokens couleurs
│   │   │   ├── theme/              # ThemeData (Dark/Light avec palette Bleu/Or)
│   │   │   ├── network/            # Client Dio, WebSocket channel, MQTT client
│   │   │   ├── discovery/          # Découverte mDNS / UDP broadcast
│   │   │   └── storage/            # Stockage local sécurisé (flutter_secure_storage / SQLite)
│   │   ├── features/
│   │   │   ├── onboarding/         # Assistant d'appairage & calibration pas à pas
│   │   │   ├── dashboard/          # Jauge animée or/bleu, niveau %, autonomie estimée
│   │   │   ├── alerts/             # Écran d'alerte critique rouge plein écran + consignes
│   │   │   ├── analytics/          # Graphiques fl_chart jour/semaine/mois, conso moyenne
│   │   │   ├── prediction/         # Moteur de prédiction Flutter (Régression + EWMA)
│   │   │   └── settings/           # Gestion seuils, tare, étalonnage, électrovanne
│   │   └── shared/
│   │       ├── models/             # Modèles Dart sérialisables (freezed / json_serializable)
│   │       └── widgets/            # Jauge circulaire dorée, cartes verre (glassmorphism)
│   └── test/                       # Tests unitaires & de widgets
├── web/                            # Application Web PWA (React 18 + TypeScript + Vite)
│   ├── package.json
│   ├── vite.config.ts              # Config Vite avec plugin PWA (vite-plugin-pwa)
│   ├── tailwind.config.ts          # Thème Tailwind basé sur shared/tokens/theme.json
│   ├── src/
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   ├── api/                    # Client API Axios / TanStack Query & WebSocket
│   │   ├── stores/                 # Stores Zustand (deviceStore, alertStore, settingsStore)
│   │   ├── hooks/                  # Hooks React (useTelemetry, useGasAlarm, usePrediction)
│   │   ├── components/
│   │   │   ├── dashboard/          # Jauge SVG circulaire dorée animée, métriques temps réel
│   │   │   ├── charts/             # Graphiques Recharts avec dégradé bleu/or
│   │   │   ├── alerts/             # Modal d'alerte critique avec sirène web audio & consignes
│   │   │   ├── wall_display/       # Mode plein écran optimisé affichage mural tablette/TV
│   │   │   └── settings/           # Formulaires de calibration, tare, seuils
│   │   ├── i18n/                   # Traductions i18next (fr.json, en.json)
│   │   └── utils/
│   │       ├── prediction.ts       # Moteur de prédiction TypeScript identique à Flutter
│   │       └── sound.ts            # Synthèse audio d'alerte Web Audio API
│   └── public/
│       ├── manifest.json           # Manifest PWA installable
│       └── icons/
└── README.md                       # Guide de démarrage rapide, architecture, tests
```

---

## 3. Décisions d'Architecture Principales (ADR)

### ADR 001 : Architecture "Local d'Abord avec Bascule Automatique Cloud"
- **Contexte** : Dans un foyer, le Wi-Fi local fonctionne même si le lien Internet ADSL/Fibre est coupé. De plus, la latence sur le réseau local est quasi-nulle (<10ms vs >150ms Cloud).
- **Décision** :
  1. L'application mobile recherche d'abord l'ESP32 via **mDNS** (`smartgas.local`) ou scan IP de sous-réseau.
  2. Si l'ESP32 répond localement, l'application se connecte en direct via **REST HTTP** et **WebSocket** (`ws://<ip>/ws`).
  3. Si la connexion locale échoue (utilisateur hors du domicile), l'application bascule automatiquement et de manière transparente sur le broker **MQTT/TLS** du backend Cloud (`wss://broker.smartgas.io:9001/mqtt` ou API FastAPI).
  4. Le schéma JSON des données télémétriques est **100% identique** entre le WebSocket local et le topic MQTT distant.

```mermaid
flowchart TD
    subgraph LAN["Réseau Local Résidentiel (Offline OK)"]
        ESP32["ESP32 (SmartGas Device)\nCapteurs + Serveur Web + WS"]
        AppLocal["App Mobile / Web Local\n(Client HTTP & WS)"]
        TFT["Écran TFT + Buzzer + LED + Électrovanne\n(Sécurité Autonome 100%)"]
        ESP32 <-->|mDNS / HTTP / WS| AppLocal
        ESP32 -->|GPIO Direct| TFT
    end

    subgraph WAN["Cloud Distant (Optionnel)"]
        MQTT["Broker Mosquitto (MQTTS:8883 / WSS:9001)"]
        FastAPI["API Backend FastAPI + DB PostgreSQL"]
        FCM["Firebase Cloud Messaging (FCM Push)"]
        MQTT <--> FastAPI
        FastAPI --> FCM
    end

    subgraph Remote["Utilisateur Hors Domicile"]
        AppRemote["App Mobile 4G/5G\n(MQTTS / API REST Cloud)"]
    end

    ESP32 -.->|MQTTS sur TLS (Optionnel)| MQTT
    FCM -.->|Push critique si fuite| AppRemote
    MQTT <-->|WSS / MQTTS| AppRemote
```

---

### ADR 002 : Priorité Matérielle et Sécurité Autonome sous FreeRTOS
- **Contexte** : La détection de fuite de gaz GPL est une question vitale (risque d'asphyxie et d'explosion). La boucle réseau (Wi-Fi, requêtes HTTP lentes, reconnexions) ne doit sous aucun prétexte bloquer l'échantillonnage des capteurs ni le déclenchement de l'alarme.
- **Décision** :
  - Utilisation de **FreeRTOS** avec séparation stricte des tâches sur les 2 cœurs de l'ESP32 :
    - **Core 0** : Tâches de connectivité (`network_task`, `mqtt_task`, `webserver_task`) à priorité moyenne (priority 2).
    - **Core 1** : Tâches matérielles critiques :
      - `sensor_task` (priority 4) : Échantillonne le HX711 (10 Hz) et le MQ-6 (1 Hz).
      - `alarm_task` (priority 5 - Priorité Maximale) : Évalue immédiatement les seuils de fuite. Si gaz ppm > seuil pendant plus de 2 secondes consécutives :
        - Active le Buzzer matériel par PWM (fréquence 2.7 kHz pulsée).
        - Active la LED stroboscopique rouge.
        - Désactive immédiatement le relais de l'électrovanne (Normalement Ouverte / Fermée selon câblage sécurisé Fail-Safe).
        - Notifie l'écran TFT pour basculer en écran rouge clignotant.
  - Watchdog matériel (Task Watchdog Timer - TWDT) configuré à 5 secondes sur les cœurs pour redémarrer automatiquement en cas de deadlock.

---

### ADR 003 : Résolution du Problème "Mixed-Content" Web (HTTPS vs HTTP ESP32)
- **Contexte** : Une PWA servie en HTTPS (ex: `https://mon-gaz.vercel.app`) ne peut pas effectuer d'appels `fetch()` ou ouvrir de `WebSocket` non sécurisé (`http://192.168.1.50/api` ou `ws://192.168.1.50/ws`) en raison de la politique de sécurité des navigateurs modernes (**Mixed-Content Blocking**).
- **Décision** :
  Deux solutions complémentaires sont fournies :
  1. **Mode Autonome Local Direct** : L'ESP32 sert directement l'interface Web PWA ultra-optimisée stockée dans sa mémoire flash LittleFS via `http://smartgas.local` ou `http://<IP_ESP32>`. Ainsi, l'origine est `http://` et il n'y a **aucun blocage mixed-content**. L'interface est installable en PWA directement depuis l'ESP32.
  2. **Mode Hybride Cloud** : Lorsque l'utilisateur utilise la version hébergée en HTTPS sur le web, la communication passe soit par le WebSocket sécurisé WSS du broker MQTT (`wss://broker.mondomaine.com:9001`), soit via l'API Gateway FastAPI HTTPS qui relaie les commandes.

---

### ADR 004 : Stratégie de l'Algorithme de Prédiction d'Autonomie
- **Contexte** : L'utilisateur a besoin de savoir avec précision quand sa bouteille sera vide (ex: "12 jours et 4 heures restants") pour anticiper son achat. La consommation d'un foyer n'est pas constante (pics à l'heure du déjeuner et du dîner, variations week-end vs semaine).
- **Décision** : Moteur de prédiction modulaire à 2 niveaux exécuté côté client (mobile & web) pour garantir la portabilité :
  - **Niveau 1 (Immédiat / Court terme)** : Régression linéaire pondérée (WLR) sur les 7 derniers jours avec coefficients de pondération exponentiels récents ($w_i = e^{\lambda (t_i - t_0)}$).
  - **Niveau 2 (Périodique & Profil de consommation)** :
    - Découpage de la semaine en 14 créneaux (7 jours $\times$ [Midi / Soir]).
    - Calcul de la consommation moyenne par créneau par lissage exponentiel (EWMA, $\alpha = 0.3$).
    - Projection de l'épuisement pas-à-pas sur les créneaux futurs pour calculer la date exacte de rupture et l'intervalle de confiance à 90%.
  - **Détection d'Anomalie (Micro-fuite)** : Si le capteur de gaz MQ ne détecte rien de critique (ppm faible sous le seuil d'alarme) mais que le poids diminue de façon continue de plus de 20g/heure la nuit (entre 01h00 et 05h00, période d'inactivité prouvée), une alerte "Suspicion de micro-fuite lente" est émise.

---

### ADR 005 : Sécurité et Appairage Zéro-Trust
- **Contexte** : Éviter qu'un voisin sur le même réseau Wi-Fi invité ou local ne puisse fermer la vanne de gaz ou modifier la calibration.
- **Décision** :
  - Au démarrage de l'appairage, l'ESP32 génère un code PIN aléatoire à 6 chiffres affiché **uniquement sur l'écran TFT physique**.
  - L'application saisit ce code pour appeler `POST /api/v1/auth/pair`.
  - L'ESP32 vérifie le code et délivre un jeton Bearer (HMAC-SHA256 basé sur une clé secrète interne générée aléatoirement au boot dans la NVS) persistant pour cet appareil.
  - Toutes les actions sensibles (`tare`, `calibrate`, `config`, `valve`) exigent ce Bearer Token dans l'en-tête `Authorization: Bearer <token>`.
