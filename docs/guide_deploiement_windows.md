# 🪟 Guide de Déploiement et Test sur Machine Windows (SmartGas ESP32)

Ce guide complet est spécialement conçu pour vous permettre de déployer, exécuter et tester la connexion avec le **prototype physique ESP32** ou le simulateur sur un ordinateur sous **Windows 10 ou Windows 11 (64-bit)** en quelques minutes.

---

## ⚡ 1. Démarrage Ultra-Rapide en 1 Clic (`start-windows.bat`)

Le projet inclut un script lanceur tout-en-un pour Windows : **[`start-windows.bat`](file:///home/t-k-f-d-m/Documents/MonGaz/start-windows.bat)**.

### Pour le lancer :
1. Ouvrez le dossier `MonGaz` dans l'Explorateur de fichiers Windows.
2. Double-cliquez simplement sur **`start-windows.bat`**.
3. Le menu interactif suivant s'affiche instantanément :

```text
=====================================================================
   🔥 SMART GAS (MonGaz) - Lanceur Rapide Windows
   Surveillance Intelligente de Bouteille de Gaz GPL (ESP32)
=====================================================================

  [1] 🔌 Tester la Connexion au Prototype ESP32 (Diagnostic Automatique)
  [2] 🚀 Lancer l'Application Web (Mode Démo / Simulateur Intégré)
  [3] 🌐 Lancer l'Application Web (Connectée au Prototype Réel sur le Wi-Fi)
  [4] ⚡ Flasher le Firmware sur l'ESP32 via USB (PlatformIO)
  [5] 📟 Ouvrir le Moniteur Série USB de l'ESP32 (115200 bauds)
  [6] 🛠️ Installer / Vérifier les Dépendances (Node.js, Python, Libs)
  [7] 📖 Ouvrir le Guide de Déploiement Windows (Documentation)
  [0] ❌ Quitter
=====================================================================
```

---

## 🧰 2. Prérequis Logiciels pour Windows

Si votre machine Windows est neuve, installez ces 3 composants gratuits (5 minutes au total) :

| Logiciel | Rôle | Lien de Téléchargement |
| :--- | :--- | :--- |
| **Python 3.10+** | Outil de test & simulateur | [python.org/downloads](https://www.python.org/downloads/) *(⚠️ Cochez **"Add Python to PATH"**)* |
| **Node.js (LTS)** | Application Web React PWA | [nodejs.org](https://nodejs.org/) *(Prenez la version LTS recommandée)* |
| **Git for Windows** | Récupération du code | [git-scm.com/download/win](https://git-scm.com/download/win) |

> [!TIP]
> Dans le menu de `start-windows.bat`, choisissez l'option **`[6]`** pour vérifier automatiquement si ces outils sont présents et installer les dépendances en un clic.

---

## 🔌 3. Pilotes USB pour Prototype ESP32 sous Windows

Lorsque vous branchez le kit ESP32 en USB sur votre PC Windows, Windows doit reconnaître la puce de conversion Série-USB présente sur la carte :

1. **Identifier la puce sur votre ESP32** :
   - La plupart des cartes ESP32 utilisent soit la puce **CH340G / CH340C** (rectangle noir marqué CH340), soit la puce **CP2102** (carrée Silicon Labs).
2. **Télécharger le pilote correspondant** si le port n'est pas reconnu :
   - Pilote **WCH CH340** (le plus fréquent) : [wch-ic.com/downloads/CH341SER_EXE.html](https://www.wch-ic.com/downloads/CH341SER_EXE.html)
   - Pilote **CP210x Silicon Labs** : [silabs.com/developers/usb-to-uart-bridge-vcp-drivers](https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers)
3. **Vérifier dans le Gestionnaire de périphériques Windows** :
   - Appuyez sur `Touche Windows + X` $\rightarrow$ sélectionnez **Gestionnaire de périphériques**.
   - Déroulez la section **"Ports (COM et LPT)"**.
   - Vous devez voir apparaître une ligne comme :  
     `USB-SERIAL CH340 (COM3)` ou `Silicon Labs CP210x USB to UART Bridge (COM4)`.

---

## 🔍 4. Tester la Connexion au Prototype Physique (Diagnostic)

Pour vérifier immédiatement si votre PC Windows communique avec le prototype physique, vous disposez de deux méthodes automatiques :

### Méthode 1 : Via l'outil de diagnostic Python / Batch (Recommandé)
Dans `start-windows.bat`, tapez **`1`** ou exécutez dans un terminal Windows (PowerShell ou Invite de commandes) :
```cmd
python tools\test_prototype.py
```

L'outil :
1. Détecte les **ports USB COM** actifs sur Windows.
2. Tente de contacter l'ESP32 sur le réseau Wi-Fi via **`smartgas.local`** (mDNS) ou vous demande son adresse IP.
3. Affiche en direct le tableau de bord de communication :

```text
┌───────────────────────────────────────────────────────────────┐
│  🟢 PROTOTYPE SMARTGAS EN LIGNE SUR : 192.168.1.50            │
│  Temps de réponse réseau : 14.2 ms                            │
├───────────────────────────────────────────────────────────────┤
│  Identifiant Boîtier  : ESP32-SMARTGAS-A48F                   │
│  Version Firmware     : 1.0.0                                 │
│  Masse de gaz restant : 8.42 kg (67.4 %)                      │
│  Capteur de Gaz MQ-6  : 145 ppm  --> ✅ Normal (Aucune fuite) │
│  Électrovanne         : OUVERTE (Gaz passant)                 │
│  Température / Humid. : 22.4 °C / 51.0 %                      │
│  Signal Wi-Fi (RSSI)  : -62 dBm                               │
└───────────────────────────────────────────────────────────────┘
```

4. Vous permet d'envoyer des commandes de test directes :
   - **`[2]` & `[3]`** : Ouvrir / Fermer l'électrovanne (test du relais physique).
   - **`[4]`** : Faire la Tare mécanique (remise à 0.00 kg).
   - **`[6]`** : Tester l'appairage avec le code PIN affiché sur l'écran TFT.

---

### Méthode 2 : Via PowerShell Natif (Sans installer Python)
Si Python n'est pas encore installé sur votre PC, utilisez le script PowerShell natif :
```powershell
powershell -ExecutionPolicy Bypass -File tools\test-prototype.ps1
```
Ce script utilise les commandes Windows natives (`[System.IO.Ports.SerialPort]` et `Invoke-RestMethod`) pour interroger l'ESP32 et afficher les métriques.

---

## 💻 5. Lancer l'Application Web connectée au Prototype Réel

Pour visualiser la jauge dorée et contrôler le boîtier physique depuis votre navigateur sur Windows :

1. Dans le menu de `start-windows.bat`, choisissez l'option **`[3]`** (Lancer connecté au Prototype Réel).
2. Saisissez l'adresse IP de votre boîtier ESP32 (ex: `192.168.1.50` ou `smartgas.local`).
3. L'application Web démarre et votre navigateur par défaut s'ouvre sur `http://localhost:3000`.
4. Toutes les requêtes HTTP `/api` et les flux temps réel WebSocket `/ws` sont automatiquement redirigés vers votre ESP32 physique !

> [!NOTE]
> Vous pouvez aussi lancer manuellement en ligne de commande sous PowerShell :
> ```powershell
> $env:VITE_ESP32_HOST="192.168.1.50"
> cd web
> npm run dev
> ```

---

## ⚡ 6. Flasher le Firmware ESP32 sous Windows (PlatformIO)

Si vous souhaitez téléverser le code C++ sur l'ESP32 depuis Windows :

### Option A : En 1 clic avec le script
Dans `start-windows.bat`, choisissez l'option **`[4]`**.  
Le script compile le code, injecte le système de fichiers LittleFS et téléverse automatiquement sur le port COM détecté.

### Option B : Avec VS Code sous Windows
1. Installez [Visual Studio Code](https://code.visualstudio.com/).
2. Dans l'onglet Extensions (`Ctrl + Shift + X`), recherchez et installez **PlatformIO IDE**.
3. Ouvrez le dossier `firmware` dans VS Code.
4. Cliquez sur l'icône **PlatformIO** (tête d'alien à gauche) :
   - Cliquez sur **`Build`** pour vérifier la compilation.
   - Cliquez sur **`Upload`** pour flasher via USB.
   - Cliquez sur **`Upload Filesystem Image`** pour flasher la WebUI LittleFS.
   - Cliquez sur **`Monitor`** pour voir les logs série en direct à 115200 bauds.

---

## 🛡️ 7. Pare-Feu Windows Defender

Lors de la première exécution de `npm run dev` ou du script Python, Windows Defender peut afficher une fenêtre pop-up :  
`"Le Pare-feu Windows Defender a bloqué certaines fonctionnalités de cette application"`.

- **Action requise** : Cochez **"Réseaux privés (tels que le réseau domestique ou professionnel)"** et cliquez sur **"Autoriser l'accès"**.
- Cela permet à votre téléphone portable ou à votre ESP32 d'accéder au serveur hébergé sur votre PC Windows.

---

## ❓ 8. Guide de Dépannage Windows (F.A.Q.)

### Le port COM n'apparaît pas quand je branche l'ESP32 ?
1. Vérifiez votre câble USB : de nombreux câbles de charge pour smartphone ne contiennent que les fils d'alimentation (+5V et GND) et **pas les fils de données (D+ et D-)**. Testez avec un autre câble USB certifié données.
2. Réinstallez le pilote **CH340** ou **CP2102** (voir section 3).
3. Changez de port USB (privilégiez les ports USB directs sur la carte mère à l'arrière d'une tour, plutôt qu'un hub USB non alimenté).

### L'ESP32 refuse le téléversement ("Failed to connect to ESP32: Timed out waiting for packet header") ?
- Certaines cartes ESP32 nécessitent de maintenir enfoncé le bouton physique **BOOT** (ou **IO0**) sur la carte au moment où PlatformIO affiche `Connecting........_____`. Relâchez-le dès que l'écriture commence (`Writing at 0x...`).

### La commande `python` ou `npm` n'est pas reconnue dans PowerShell ?
- Fermez et rouvrez votre fenêtre PowerShell ou redémarrez votre session Windows après avoir installé Python et Node.js pour que les nouvelles variables d'environnement `PATH` soient prises en compte.

### `smartgas.local` ne répond pas ?
- Sur certaines versions de Windows, le service mDNS peut être désactivé. Utilisez simplement l'**adresse IP directe** de l'ESP32 (ex: `192.168.1.50`), visible sur l'écran TFT du boîtier ou dans la console série USB.
