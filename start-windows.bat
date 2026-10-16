@echo off
chcp 65001 > nul
title SMARTGAS (MonGaz) - Lanceur Windows ^& Diagnostic Prototype
color 0B

:: Se positionner dans le dossier du script
cd /d "%~dp0"

:MENU
cls
echo =====================================================================
echo    🔥 SMART GAS (MonGaz) - Lanceur Rapide Windows
echo    Surveillance Intelligente de Bouteille de Gaz GPL (ESP32)
echo =====================================================================
echo.
echo   [1] 🔌 Tester la Connexion au Prototype ESP32 (Diagnostic Automatique)
echo   [2] 🚀 Lancer l'Application Web (Mode Démo / Simulateur Intégré)
echo   [3] 🌐 Lancer l'Application Web (Connectée au Prototype Réel sur le Wi-Fi)
echo   [4] ⚡ Flasher le Firmware sur l'ESP32 via USB (PlatformIO)
echo   [5] 📟 Ouvrir le Moniteur Série USB de l'ESP32 (115200 bauds)
echo   [6] 🛠️ Installer / Vérifier les Dépendances (Node.js, Python, Libs)
echo   [7] 📖 Ouvrir le Guide de Déploiement Windows (Documentation)
echo   [8] 🖥️ Lancer la Version Desktop Windows (SmartGas.exe)
echo   [9] 📦 Compiler l'Exécutable Windows (.exe)
echo   [0] ❌ Quitter
echo.
echo =====================================================================
set /p CHOICE="Entrez votre choix [0-9] : "

if "%CHOICE%"=="1" goto TEST_CONNECTION
if "%CHOICE%"=="2" goto LAUNCH_SIM_WEB
if "%CHOICE%"=="3" goto LAUNCH_REAL_WEB
if "%CHOICE%"=="4" goto FLASH_FIRMWARE
if "%CHOICE%"=="5" goto SERIAL_MONITOR
if "%CHOICE%"=="6" goto INSTALL_DEPS
if "%CHOICE%"=="7" goto OPEN_DOCS
if "%CHOICE%"=="8" goto LAUNCH_DESKTOP
if "%CHOICE%"=="9" goto BUILD_DESKTOP
if "%CHOICE%"=="0" goto EXIT_SCRIPT

echo.
echo Choix invalide. Veuillez réessayer.
timeout /t 2 > nul
goto MENU

:: ---------------------------------------------------------
:: 1. TEST DE CONNEXION AU PROTOTYPE
:: ---------------------------------------------------------
:TEST_CONNECTION
cls
echo =====================================================================
echo   🔌 Diagnostic et Test de Connexion au Prototype ESP32
echo =====================================================================
echo.
echo Recherche de Python sur votre machine...
where python >nul 2>nul
if %errorlevel% neq 0 (
    where py >nul 2>nul
    if %errorlevel% neq 0 (
        echo [ATTENTION] Python n'est pas détecté dans votre variable PATH.
        echo Lancement du diagnostic alternatif en PowerShell...
        echo.
        powershell -ExecutionPolicy Bypass -File "%~dp0tools\test-prototype.ps1"
        pause
        goto MENU
    ) else (
        py "%~dp0tools\test_prototype.py"
    )
) else (
    python "%~dp0tools\test_prototype.py"
)
pause
goto MENU

:: ---------------------------------------------------------
:: 2. LANCER SIMULATEUR + WEB
:: ---------------------------------------------------------
:LAUNCH_SIM_WEB
cls
echo =====================================================================
echo   🚀 Lancement de l'Application Web avec Simulateur Intégré
echo =====================================================================
echo.
echo 1. Démarrage du Simulateur ESP32 sur le port 8080...
start "SmartGas ESP32 Simulator (Port 8080)" cmd /k "cd /d "%~dp0" && (python shared\demo\demo_simulator.py || py shared\demo\demo_simulator.py)"

echo 2. Attente de l'initialisation du serveur (2 secondes)...
timeout /t 2 > nul

echo 3. Démarrage de l'Application Web Vite sur le port 3000...
start "SmartGas Web PWA (Port 3000)" cmd /k "cd /d "%~dp0web" && npm run dev"

echo.
echo Les serveurs sont lancés dans deux fenêtres d'arrière-plan distinctes.
echo Ouverture de l'application dans votre navigateur par défaut...
timeout /t 3 > nul
start http://localhost:3000

echo.
echo ✅ Application disponible sur : http://localhost:3000
echo.
pause
goto MENU

:: ---------------------------------------------------------
:: 3. LANCER WEB CONNECTÉ AU PROTOTYPE RÉEL
:: ---------------------------------------------------------
:LAUNCH_REAL_WEB
cls
echo =====================================================================
echo   🌐 Lancement de l'Application Web connectée au Prototype Réel
echo =====================================================================
echo.
echo Entrez l'adresse IP de votre boîtier ESP32 sur votre réseau Wi-Fi :
echo (Exemple : 192.168.1.50 ou smartgas.local)
set /p ESP_IP="Adresse IP du boîtier [défaut: smartgas.local] : "
if "%ESP_IP%"=="" set ESP_IP=smartgas.local

echo.
echo Configuration de la cible ESP32 : http://%ESP_IP%
set VITE_ESP32_HOST=%ESP_IP%

echo Démarrage de l'Application Web...
start "SmartGas Web PWA (ESP32 Réel)" cmd /k "cd /d "%~dp0web" && npm run dev"

timeout /t 3 > nul
start http://localhost:3000
pause
goto MENU

:: ---------------------------------------------------------
:: 4. FLASHER LE FIRMWARE (PLATFORMIO)
:: ---------------------------------------------------------
:FLASH_FIRMWARE
cls
echo =====================================================================
echo   ⚡ Compilation et Téléversement du Firmware ESP32
echo =====================================================================
echo.
echo Assurez-vous que le kit ESP32 est branché en USB sur votre PC Windows.
echo.
where pio >nul 2>nul
if %errorlevel% neq 0 (
    echo [INFO] PlatformIO CLI n'est pas dans le PATH global.
    echo Vérification de l'installation dans Python / VS Code...
    python -m platformio --version >nul 2>nul
    if %errorlevel% equ 0 (
        set PIO_CMD=python -m platformio
    ) else (
        echo.
        echo ❌ PlatformIO n'a pas été trouvé.
        echo Vous pouvez l'installer facilement en ouvrant VS Code avec l'extension
        echo 'PlatformIO IDE', ou en exécutant : pip install platformio
        echo.
        pause
        goto MENU
    )
) else (
    set PIO_CMD=pio
)

echo.
echo 1. Compilation et téléversement du binaire principal...
%PIO_CMD% run -d "%~dp0firmware" -e esp32dev --target upload
if %errorlevel% neq 0 (
    echo.
    echo ❌ Erreur lors du téléversement.
    echo Vérifiez que le port COM n'est pas utilisé par un autre logiciel
    echo et que le câble USB gère bien les données (Data + Power).
    pause
    goto MENU
)

echo.
echo 2. Téléversement du système de fichiers LittleFS (WebUI embarquée)...
%PIO_CMD% run -d "%~dp0firmware" -e esp32dev --target uploadfs

echo.
echo ✅ Firmware flashé avec succès sur le prototype !
echo.
pause
goto MENU

:: ---------------------------------------------------------
:: 5. MONITEUR SÉRIE USB
:: ---------------------------------------------------------
:SERIAL_MONITOR
cls
echo =====================================================================
echo   📟 Moniteur Série USB ESP32 (Vitesse : 115200 bauds)
echo =====================================================================
echo (Appuyez sur Ctrl+C pour quitter le moniteur)
echo.
where pio >nul 2>nul
if %errorlevel% equ 0 (
    pio device monitor -d "%~dp0firmware" -b 115200
) else (
    python -m platformio device monitor -d "%~dp0firmware" -b 115200
)
pause
goto MENU

:: ---------------------------------------------------------
:: 6. INSTALLER / VÉRIFIER LES DÉPENDANCES
:: ---------------------------------------------------------
:INSTALL_DEPS
cls
echo =====================================================================
echo   🛠️ Vérification et Installation des Dépendances Windows
echo =====================================================================
echo.

echo [1/3] Vérification de Python...
where python >nul 2>nul
if %errorlevel% equ 0 (
    python --version
    echo Installation de aiohttp pour le simulateur...
    pip install aiohttp
) else (
    echo ❌ Python non trouvé ! Téléchargez-le sur : https://www.python.org/downloads/
)

echo.
echo [2/3] Vérification de Node.js et NPM...
where npm >nul 2>nul
if %errorlevel% equ 0 (
    npm --version
    echo Installation des modules Web React...
    cd /d "%~dp0web"
    call npm install
    cd /d "%~dp0"
) else (
    echo ❌ Node.js non trouvé ! Téléchargez-le sur : https://nodejs.org/
)

echo.
echo [3/3] Vérification de PlatformIO...
where pio >nul 2>nul
if %errorlevel% neq 0 (
    echo Installation optionnelle de PlatformIO via pip...
    pip install platformio
) else (
    echo ✅ PlatformIO CLI est déjà installé.
)

echo.
echo ✅ Vérification terminée !
pause
goto MENU

:: ---------------------------------------------------------
:: 7. OUVRIR LA DOCUMENTATION
:: ---------------------------------------------------------
:OPEN_DOCS
start "" "%~dp0docs\guide_deploiement_windows.md"
goto MENU

:: ---------------------------------------------------------
:: 8. LANCER LA VERSION DESKTOP WINDOWS
:: ---------------------------------------------------------
:LAUNCH_DESKTOP
cls
echo =====================================================================
echo   🖥️ Lancement de SMART GAS Desktop (Application Windows Native)
echo =====================================================================
echo.
if exist "%~dp0desktop\dist-electron\SmartGas-Portable-1.0.0.exe" (
    echo Démarrage de SmartGas Portable (.exe)...
    start "" "%~dp0desktop\dist-electron\SmartGas-Portable-1.0.0.exe"
    goto MENU
)
if exist "%~dp0desktop\dist-electron\win-unpacked\SmartGas.exe" (
    echo Démarrage de SmartGas (.exe)...
    start "" "%~dp0desktop\dist-electron\win-unpacked\SmartGas.exe"
    goto MENU
)

echo [INFO] Aucun binaire précompilé détecté dans dist-electron.
echo Lancement de l'application Desktop en mode développement avec Electron...
cd /d "%~dp0desktop"
call npm start
cd /d "%~dp0"
pause
goto MENU

:: ---------------------------------------------------------
:: 9. COMPILER L'EXÉCUTABLE WINDOWS (.EXE)
:: ---------------------------------------------------------
:BUILD_DESKTOP
cls
echo =====================================================================
echo   📦 Compilation de l'Exécutable Windows (.exe)
echo =====================================================================
echo.
echo 1. Compilation des sources Web (Vite + React)...
cd /d "%~dp0web"
call npm run build
if %errorlevel% neq 0 (
    echo ❌ Échec du build Web.
    pause
    goto MENU
)

echo.
echo 2. Installation des modules Electron...
cd /d "%~dp0desktop"
call npm install

echo.
echo 3. Création des exécutables Windows (.exe) via Electron Builder...
call npm run dist:win

echo.
echo ✅ Exécutables disponibles dans le dossier : desktop\dist-electron\
echo.
cd /d "%~dp0"
pause
goto MENU

:EXIT_SCRIPT
exit /b 0
