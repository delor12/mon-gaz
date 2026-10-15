# Schéma de Câblage Matériel et Liste des Composants (BOM)

Ce document détaille la nomenclature matérielle (BOM) et le schéma d'interconnexion physique complet pour le prototype connecté **SmartGas**.

---

## 1. Nomenclature Matérielle (Bill of Materials - BOM)

| Désignation | Modèle Recommandé | Rôle & Spécifications | Alimentation |
| :--- | :--- | :--- | :--- |
| **Microcontrôleur** | ESP32-WROOM-32D (30 ou 38 broches) | Cœur de calcul, double cœur 240 MHz, Wi-Fi 2.4 GHz + BLE 4.2 | 5V via Micro-USB ou broche VIN |
| **Cellule de Pesée** | Barreau d'aluminium 40 kg ou 50 kg (4 jauges de contrainte pont de Wheatstone) | Mesure du poids brut de la bouteille (bouteille vide ~13 kg + gaz 12.5 kg = ~25.5 kg) | 5V (fourni par HX711) |
| **Amplificateur ADC** | HX711 (carte violette ou verte avec blindage) | Convertisseur Analogique-Numérique 24 bits haute précision | 3.3V ou 5V VCC |
| **Capteur de Gaz** | MQ-6 (spécial GPL, Isobutane, Propane) ou MQ-2 | Détection précoce des fuites de gaz combustibles | 5V VCC (chauffage ~800 mW) |
| **Capteur Temp/Hum** | DHT22 (AM2302) ou Bosch BME280 | Compensation thermique du capteur de gaz et température ambiante | 3.3V VCC |
| **Écran d'Affichage** | TFT LCD 2.0" ou 2.4" SPI (ST7789 ou ILI9341, 240x320) | Affichage local en direct du poids, du niveau %, du Wi-Fi et des alertes | 3.3V VCC |
| **Avertisseur Sonore** | Buzzer Piezo Actif ou Passif 5V (85 dB @ 10cm) | Alarme sonore stridente locale autonome | 5V piloté par transistor NPN |
| **Avertisseur Lumineux** | LED Rouge 5mm ou 10mm Ultra-lumineuse | Témoin visuel clignotant stroboscopique | 3.3V (via résistance 220 $\Omega$) |
| **Module Relais** | Relais Optocouplé 1 canal 5V (avec diode Flyback) | Coupure d'urgence de l'électrovanne de gaz | 5V VCC / Signal 3.3V |
| **Électrovanne (Option)** | Électrovanne 12V DC normalement fermée (NC) pour gaz GPL | Coupure mécanique du flux de gaz | Alimentation séparée 12V 1A |
| **Bouton d'Appairage** | Bouton poussoir momentané NO | Déclenchement de la session d'appairage PIN sur l'écran | Entrée 3.3V avec pull-up interne |
| **Alimentation Générale** | Bloc secteur 5V DC 2.5A (ou 3A) + connecteur jack/USB | Alimentation stable filtrée | Secteur 230V AC |

---

## 2. Table d'Assignation des Broches GPIO de l'ESP32

| Composant | Broche Composant | Broche ESP32 (GPIO) | Type I/O | Remarques Électriques |
| :--- | :--- | :--- | :--- | :--- |
| **HX711** | DOUT (Data) | **GPIO 21** | Entrée Numérique | Bus série synchrone HX711 |
| **HX711** | SCK (Clock) | **GPIO 22** | Sortie Numérique | Horloge d'échantillonnage 10 Hz |
| **MQ-6 Gaz** | AOUT (Analog) | **GPIO 34** | Entrée Analogique | **ADC1_CH6** (impératif car Wi-Fi désactive ADC2) |
| **DHT22** | DATA | **GPIO 32** | E/S Numérique | Résistance de tirage 10 k$\Omega$ vers 3.3V |
| **Buzzer** | Base Transistor / IN | **GPIO 25** | Sortie PWM | Canal LEDC_0 (2700 Hz) via transistor 2N2222 |
| **LED Alerte** | Anode (+) | **GPIO 26** | Sortie Numérique | Résistance série 220 $\Omega$ vers la masse |
| **Relais Vanne** | IN | **GPIO 27** | Sortie Numérique | Commande active BAS ou HAUT (optocouplée) |
| **Bouton Pair** | Contact 1 | **GPIO 33** | Entrée Numérique | Pull-up interne activé (Contact 2 vers GND) |
| **Écran TFT** | MOSI (SDA) | **GPIO 23** | SPI MOSI | Matériel SPI VSPI |
| **Écran TFT** | SCLK (SCK) | **GPIO 18** | SPI SCLK | Matériel SPI VSPI (40 MHz) |
| **Écran TFT** | CS | **GPIO 5** | Sortie Numérique | Chip Select écran |
| **Écran TFT** | DC (A0) | **GPIO 2** | Sortie Numérique | Data / Command select |
| **Écran TFT** | RST | **GPIO 4** | Sortie Numérique | Reset matériel écran |
| **Écran TFT** | BL (Backlight) | **GPIO 15** | Sortie Numérique | Contrôle rétroéclairage (ou 3.3V direct) |

---

## 3. Schéma de Câblage Détaillé

### 3.1. Cellule de Pesée vers Amplificateur HX711
Le pont de Wheatstone de la cellule 4 fils se raccorde sur le bornier du HX711 :
- **Fil ROUGE** : `E+` (Excitation positive)
- **Fil NOIR** : `E-` (Excitation négative / GND)
- **Fil BLANC** : `A-` (Signal différentiel -)
- **Fil VERT** : `A+` (Signal différentiel +)

Le HX711 est ensuite relié à l'ESP32 :
- `VCC` $\rightarrow$ 3.3V (ou 5V si le module possède son propre régulateur 3.3V interne)
- `GND` $\rightarrow$ Masse Commune (GND)
- `DT` $\rightarrow$ **GPIO 21**
- `SCK` $\rightarrow$ **GPIO 22**

### 3.2. Capteur de Gaz MQ-6
Le filament chauffant du MQ-6 nécessite une alimentation 5V stable (courant ~160 mA) :
- `VCC` $\rightarrow$ **Rail 5V (VIN)**
- `GND` $\rightarrow$ **GND Commune**
- `AOUT` $\rightarrow$ **GPIO 34** de l'ESP32
> *Note de tension* : Le diviseur interne du module MQ-6 délivre entre 0.1V et 3.3V en plage normale. Si la tension de sortie dépasse 3.3V en cas de saturation extrême, insérer un diviseur de tension résistif (1 k$\Omega$ / 2 k$\Omega$) pour protéger l'entrée ADC de l'ESP32.

### 3.3. Circuit Commande du Buzzer (Driver Transistor NPN)
Ne pas alimenter un buzzer puissant directement sur une broche GPIO (limite 12 mA). Utiliser un transistor NPN 2N2222 :
```text
           Rail +5V
              │
          ┌───┴───┐
          │ Buzzer│
          └───┬───┘
              │ Collecteur
GPIO 25 ────[ 1kΩ ]───┤ Base (2N2222)
                      │ Émetteur
                     GND
```

### 3.4. Module Relais & Électrovanne de Sécurité
- Le relais optocouplé est alimenté en 5V (`VCC` sur 5V, `GND` sur GND).
- L'entrée `IN` est branchée sur **GPIO 27**.
- Le circuit de l'électrovanne 12V passe par les contacts **COM** (Commun) et **NO** (Normalement Ouvert) du relais, alimenté par le transformateur 12V indépendant.
- En cas de coupure secteur ou de signal d'urgence de l'ESP32, le relais retombe et coupe l'alimentation de l'électrovanne, bloquant immédiatement le gaz.

---

## 4. Recommandations de Sécurité Électrique en Milieu Gaz GPL
1. **Éloignement de la source de gaz** : Le boîtier électronique principal (ESP32, relais, alimentation) doit être situé à **au moins 50 cm à 1 mètre** de la bouteille ou dans un compartiment ventilé distinct.
2. **Capteur MQ déporté** : Le capteur MQ-6 doit être placé **en position basse** (à 10-20 cm du sol), car les gaz GPL (Butane et Propane) sont plus lourds que l'air ($d \approx 1.5$ à $2.0$) et s'accumulent au niveau du sol en cas de fuite.
3. **Absence d'étincelles** : Utiliser un relais étanche ou de type statique (Solid State Relay / Mosfet) de préférence pour éviter toute étincelle de commutation à proximité immédiate d'une fuite.
