# 🔌 Guide de Connexion et d'Appairage du Kit ESP32 SmartGas

Ce guide pas à pas vous explique comment alimenter, connecter au Wi-Fi et appairer votre kit matériel **SmartGas (ESP32)** avec l'application mobile (Flutter) ou l'application web (React/PWA).

---

## 🧰 1. Mise Sous Tension du Kit

1. Branchez votre boîtier SmartGas à une prise secteur via son câble **USB 5V (2A recommandé)** ou son adaptateur secteur.
2. Basculez l'interrupteur d'alimentation sur **ON**.
3. Observez l'écran TFT physique du kit :
   - L'écran s'allume avec le logo `SMART GAS Initialisation v1.0...`.
   - La LED rouge clignote brièvement (auto-test matériel).
   - Le buzzer émet un bip court de confirmation.

---

## 📶 2. Première Connexion Wi-Fi (Portail Captif)

Lors du tout premier allumage (ou si vous changez de box Wi-Fi), l'ESP32 ne connaît pas encore votre réseau domestique. Il démarre automatiquement en mode **Point d'Accès de Configuration** :

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. Sur votre smartphone ou ordinateur :                     │
│    Allez dans Paramètres Wi-Fi et connectez-vous au réseau :│
│                                                             │
│    Nom du réseau (SSID) : SmartGas-Setup                    │
│    Mot de passe        : smartgas123                        │
└─────────────────────────────────────────────────────────────┘
```

2. Dès la connexion, une notification de **Portail Captif** apparaît (ou ouvrez votre navigateur web sur l'adresse : `http://192.168.4.1`).
3. La page de configuration s'affiche :
   - Sélectionnez le **nom de votre box Wi-Fi (SSID)** (ex: `Livebox-5B20`, `Freebox-XYZ`).
   - Saisissez votre **clé de sécurité Wi-Fi**.
   - Cliquez sur **"Enregistrer et Redémarrer"**.
4. L'ESP32 redémarre et se connecte à votre réseau Wi-Fi résidentiel.
5. **Vérification sur l'écran TFT** :
   - En haut à droite, l'indicateur affiche **`Wi-Fi OK`** en vert avec la puissance du signal (ex: `-62 dBm`).

---

## 🔗 3. Appairage Sécurisé avec l'Application (Code PIN Écran TFT)

Pour éviter que des tiers sur votre réseau local ne puissent modifier vos paramètres, l'ESP32 utilise un protocole d'appairage par code physique :

### Étape A : Génération du code PIN sur le boîtier
1. Appuyez pendant **2 secondes sur le bouton physique "Pair"** (situé sur le côté du boîtier SmartGas).
2. L'écran TFT affiche l'écran d'appairage :
   ```text
   +------------------------------------+
   |             APPAIRAGE              |
   |                                    |
   |     Saisissez ce code PIN dans     |
   |    l'application mobile/web :      |
   |                                    |
   |         ┌────────────────┐         |
   |         │   [ 482 910 ]  │         |
   |         └────────────────┘         |
   |                                    |
   |     Expire dans : 180 secondes     |
   +------------------------------------+
   ```

### Étape B : Saisie dans l'Application (Mobile ou Web)
1. Ouvrez l'application **SmartGas** sur votre téléphone ou sur le navigateur web.
2. Si c'est votre première utilisation, l'écran d'appairage s'affiche automatiquement.
3. Saisissez le **code PIN à 6 chiffres** affiché sur l'écran physique.
4. Cliquez sur **"Valider l'Appairage"**.
5. L'ESP32 valide le code et délivre un jeton sécurisé (*Bearer Token*) qui est enregistré de façon chiffrée sur votre appareil.
6. L'écran TFT revient automatiquement au tableau de bord normal et affiche `0.00 kg` ou le poids actuel.

---

## 🌐 4. Comment Trouver l'Adresse de Votre Boîtier

L'application détecte automatiquement le boîtier par trois moyens :

1. **Découverte Automatique mDNS (Zéro configuration)** :
   - L'application contacte automatiquement `http://smartgas.local`.
   - Fonctionne nativement sur iPhone (iOS), Mac, Windows 10/11 et Linux.
2. **Adresse IP Locale Directe (Si mDNS est bloqué par votre box)** :
   - Vous pouvez lire l'adresse IP assignée à l'ESP32 sur la console série USB ou dans l'interface d'administration de votre box Internet (ex: `192.168.1.50`).
   - Dans l'application, ouvrez **Paramètres (⚙️)** $\rightarrow$ **"Adresse Réseau de l'ESP32"** $\rightarrow$ entrez `192.168.1.50` et cliquez sur **"Enregistrer"**.
3. **Accès Public Distant (Hors de la maison)** :
   - Entrez simplement le lien de votre tunnel sécurisé (ex: `https://votre-tunnel.trycloudflare.com`).

---

## 🛠️ 5. Vérification Rapide de la Bonne Communication

Une fois connecté, effectuez ce test rapide de 30 secondes pour vérifier que tout communique :

1. **Test de la jauge** :
   - Appuyez légèrement avec la main sur le plateau de pesée du kit.
   - La jauge dorée et la valeur numérique sur l'application doivent réagir immédiatement en direct (< 1 seconde).
2. **Test de la vanne de sécurité** :
   - Dans l'application, appuyez sur le bouton **"Fermer Électrovanne"**.
   - Vous devez entendre le clic sec caractéristique du relais physique sur l'ESP32, et l'écran TFT affiche `Vanne: FERMÉE`.
   - Appuyez sur **"Ouvrir Électrovanne"** pour la réarmer.
3. **Test de la Tare** :
   - Enlevez toute charge du plateau.
   - Cliquez sur **"Tare (0 kg)"** dans l'application.
   - L'application et l'écran TFT doivent afficher exactement `0.00 kg`.

---

## ❓ 6. Dépannage (F.A.Q.)

### L'application affiche "Hors Ligne" ?
- Vérifiez que votre smartphone est bien connecté au **même réseau Wi-Fi 2.4 GHz** que l'ESP32 (l'ESP32 ne se connecte pas sur la bande 5 GHz).
- Ouvrez les **Paramètres (⚙️)** de l'application et renseignez manuellement l'adresse IP locale du boîtier (ex: `192.168.1.50`).

### Comment réinitialiser les réglages Wi-Fi de l'ESP32 ?
- Maintenez le bouton physique "Pair" enfoncé pendant **plus de 10 secondes** lors du démarrage de l'appareil.
- L'ESP32 efface la mémoire NVS et redémarre en mode point d'accès `SmartGas-Setup`.

### Le capteur de gaz indique "[CHAUFFAGE]" ?
- C'est normal : le capteur MQ-6 dispose d'une phase de préchauffage automatique de 30 secondes au démarrage pour garantir des mesures fiables et éviter les faux positifs.

---

> 🔒 **Besoin d'aide ?** Consultez le schéma électrique complet dans [`docs/wiring_schematic.md`](file:///home/t-k-f-d-m/Documents/MonGaz/docs/wiring_schematic.md) ou le guide de calibration dans [`docs/calibration_guide.md`](file:///home/t-k-f-d-m/Documents/MonGaz/docs/calibration_guide.md).
