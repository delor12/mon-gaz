# 🖥️ Guide de la Version Desktop Windows (.exe) - SMART GAS

Ce guide explique comment installer, exécuter et compiler la **version Desktop native Windows (`.exe`)** de l'application SMART GAS.

---

## 🌟 Avantages de la Version Desktop Windows

Contrairement à une simple page web dans un navigateur, l'application Desktop Windows offre :

1. **Surveillance Permanente en Arrière-Plan (Barre des tâches / System Tray)** :
   - L'application se loge discrètement dans la zone de notification Windows (à côté de l'horloge).
   - Lorsque vous fermez la fenêtre principale, la surveillance continue à 10 Hz sans interruption.
2. **Alertes Natives Windows (Toasts & Sons Prioritaires)** :
   - En cas de fuite de gaz détectée par le MQ-6, une notification Windows système stridente apparaît immédiatement au premier plan, même si votre écran est verrouillé ou si une autre application est active.
3. **Liaison Réseau Locale Directe Inviolable** :
   - Aucune restriction CORS : l'application communique directement avec l'ESP32 en local (`http://192.168.1.192` ou `http://smartgas.local`) et par WebSocket sans passer par le cloud.
4. **Zéro Dépendance** :
   - Pas besoin de lancer un terminal, de taper des commandes `npm` ou de configurer un serveur web. L'exécutable `.exe` embarque tout le moteur d'exécution.

---

## 🚀 1. Comment Lancer la Version Desktop sur Windows

Vous avez deux façons simples d'utiliser la version Desktop sur votre PC Windows :

### Méthode A : Exécution Directe de l'Exécutable Portable (`SmartGas.exe`)
1. Dans le dossier `desktop/dist-electron/win-unpacked/` :
2. Double-cliquez directement sur **`SmartGas.exe`**.
3. L'application démarre immédiatement avec l'écran bleu profond et la jauge dorée.

### Méthode B : Via le Lanceur Windows en 1 Clic (`start-windows.bat`)
1. Double-cliquez sur **`start-windows.bat`** à la racine du projet.
2. Tapez **`8`** pour lancer directement la version Desktop Windows.

---

## 📦 2. Téléchargement Automatique depuis GitHub Releases

Grâce au workflow GitHub Actions configuré dans [`.github/workflows/ci-windows-desktop.yml`](file:///home/t-k-f-d-m/Documents/MonGaz/.github/workflows/ci-windows-desktop.yml) :
- À chaque nouvelle mise à jour ou tag de version sur GitHub, les exécutables Windows sont compilés automatiquement sur les machines virtuelles Windows de GitHub.
- Les fichiers `.exe` sont disponibles au téléchargement dans l'onglet **Actions** et **Releases** de votre dépôt :
  👉 **[https://github.com/delor12/mon-gaz/releases](https://github.com/delor12/mon-gaz/releases)**

Fichiers fournis :
- **`SmartGas-Portable-1.0.0.exe`** : Exécutable autonome tout-en-un (aucun dossier requis, portable sur clé USB).
- **`SmartGas-Setup-1.0.0.exe`** : Installateur Windows officiel avec raccourci sur le Bureau et menu Démarrer.
- **`SmartGas-Windows-x64.zip`** : Archive zip contenant l'application prête à l'emploi.

---

## 🛠️ 3. Compiler l'Exécutable `.exe` vous-même sous Windows

Si vous souhaitez recompiler l'exécutable après avoir modifié le code source :

1. Assurez-vous d'avoir installé **Node.js LTS** (version 20 ou 22).
2. Ouvrez une invite de commandes dans le dossier du projet :
   ```cmd
   cd web
   npm run build
   cd ../desktop
   npm install
   npm run dist:win
   ```
3. L'exécutable compilé se trouvera dans le dossier `desktop/dist-electron/win-unpacked/SmartGas.exe` !

---

## 🎯 4. Configuration de la Cible ESP32 dans l'Application Desktop

Au lancement de l'application Desktop :
- Le menu supérieur **"ESP32 & Réseau"** vous permet de :
  - Vous connecter au **Simulateur local** (`localhost:8080`) pour tester immédiatement.
  - Basculer sur votre **vrai boîtier ESP32** sur le réseau (ex: `192.168.1.192` ou `smartgas.local`).
- Les raccourcis utiles :
  - **F11** : Basculer en mode Plein Écran (idéal pour un écran tactile mural de cuisine).
  - **Ctrl + R** : Actualiser l'interface.
  - **Ctrl + Q** : Quitter complètement l'application (ferme également l'icône dans la zone de notification).
