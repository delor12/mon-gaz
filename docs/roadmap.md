# Feuille de Route Technologique (Roadmap) - SmartGas

Ce document présente les évolutions d'ingénierie matérielle, logicielle et domotique planifiées pour les versions 2.0 et ultérieures de **SmartGas**.

---

## 1. Intégration Domotique Native : Home Assistant (MQTT Discovery)

L'objectif est d'intégrer SmartGas au hub domotique open-source de référence sans aucune configuration manuelle de fichiers YAML.

### Spécifications Techniques :
- **Protocole MQTT Discovery Home Assistant** :
  - Dès sa connexion au broker, l'ESP32 publie sur le topic de configuration standard :
    `homeassistant/sensor/smartgas_8a4f/weight/config`
  - Payload JSON de découverte automatique :
    ```json
    {
      "name": "Niveau Gaz Cuisine",
      "state_topic": "smartgas/ESP32-SMARTGAS-8A4F/telemetry",
      "value_template": "{{ value_json.weight_kg }}",
      "unit_of_measurement": "kg",
      "device_class": "weight",
      "icon": "mdi:gas-cylinder",
      "device": {
        "identifiers": ["smartgas_8a4f"],
        "name": "SmartGas Moniteur",
        "model": "SG-V1",
        "manufacturer": "SmartGas Lab"
      }
    }
    ```
- **Entités Publiées Automatiquement** :
  - `sensor.gaz_poids_net` (kg)
  - `sensor.gaz_niveau_pourcent` (%)
  - `sensor.gaz_ppm` (ppm)
  - `binary_sensor.gaz_fuite` (device_class: `gas`, alerte critique)
  - `switch.gaz_electrovanne` (commande d'ouverture/fermeture avec sécurité)
- **Carte Lovelace Personnalisée** : Développement d'un composant Web Component reprenant la jauge dorée circulaire SmartGas directement dans l'interface Home Assistant.

---

## 2. Vanne Motorisée à Bille Bistable (Ultra-Basse Consommation)

Dans le prototype V1, une électrovanne standard pilotée par relais consomme environ 5W à 10W en continu lorsqu'elle est maintenue ouverte, provoquant un échauffement thermique de la bobine.

### Évolution Matérielle V2 :
- **Actionneur** : Vanne à boisseau sphérique motorisée 12V (filetage standard 1/2" ou 3/8" pour flexible gaz GPL) avec retour automatique ou moteur pas-à-pas bistable.
- **Circuit Driver en Pont en H (L9110S ou DRV8833)** :
  - Pour ouvrir : Impulsion électrique de 3 secondes $\rightarrow$ la bille tourne de $90^\circ$ $\rightarrow$ coupure du courant (consommation nulle au repos).
  - Pour fermer (alerte fuite) : Impulsion de polarité inversée de 3 secondes $\rightarrow$ fermeture étanche à 100%.
- **Super-condensateur de Secours (Fail-Safe)** : En cas de coupure brutale de courant 230V, l'énergie stockée dans un condensateur de 5.5V / 1.5F est immédiatement déchargée dans le moteur pour forcer la fermeture mécanique d'urgence de la vanne.

---

## 3. Capteur de Débit Massique Thermique / Ultrasonique

La balance mesure la masse globale, mais le calcul du débit instantané par dérivation mathématique ($\frac{dm}{dt}$) est sujet au bruit de mesure sur de faibles consommations (ex: petite veilleuse à 15 g/h).

### Évolution Matérielle V2.2 :
- **Insertion en ligne d'un capteur de débit thermique de gaz (MEMS Gas Flow Sensor, ex: Sensirion SFM4300 ou FS4001)** :
  - Mesure instantanée du débit volumique en $L/\text{min}$ et du flux massique en $g/\text{h}$ avec une précision de $\pm 1.5\%$.
  - Détection instantanée (en moins de 500 ms) d'un brûleur oublié ou d'une fuite sur la tuyauterie en comparant le débit mesuré à l'activité déclarée.

---

## 4. Assistants Vocaux (Matter over Thread, Alexa, Google Home)

Permettre aux utilisateurs de demander vocalement l'état de leur réserve de gaz sans manipuler leur smartphone.

### Scénarios Vocaux :
- *"Dis Google, quel est le niveau de ma bouteille de gaz ?"*
  $\rightarrow$ *"Il vous reste 8.4 kg de gaz, soit 67%. Votre réserve est suffisante pour environ 24 jours."*
- *"Alexa, préviens-moi si le gaz passe sous 15%."*
  $\rightarrow$ *"D'accord, je vous alerterai dès que le niveau descendra sous 15%."*

### Architecture Matter :
- Migration du SoC ESP32-WROOM-32D vers un **ESP32-C6 ou ESP32-H2** intégrant le support natif de **Matter over Thread** (IEEE 802.15.4 + Bluetooth LE 5.3).
- Utilisation du profil Matter standard `AirQualitySensor` et `FlowSensor` pour une compatibilité native Apple HomeKit, Google Home et Amazon Alexa sans pont intermédiaire.

---

## 5. Passerelle Cellulaire de Secours (NB-IoT / LTE-M)

Pour les résidences secondaires, campings, ou zones rurales dépourvues de réseau Wi-Fi résidentiel :
- Module d'extension **SIM7080G (LTE Cat-M1 / NB-IoT)** raccordé en UART sur GPIO 16/17 de l'ESP32.
- Émission quotidienne d'un message compact CoAP ou MQTT-SN (< 200 octets) contenant le niveau de gaz et la tension batterie.
- Autonomie sur batterie lithium LiFePO4 de plus de **24 mois** grâce aux modes Deep Sleep de l'ESP32 (réveil 1 fois par jour ou immédiat sur front montant du capteur de gaz).
