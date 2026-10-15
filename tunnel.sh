#!/bin/bash
# =============================================================================
# SMART GAS - Script de Démarrage Global & Tunnel Cloudflare Sécurisé
# =============================================================================

PORT=3000

echo "Vérification et démarrage du simulateur ESP32 (Port 8080)..."
if ! ss -tlpn | grep -q ":8080"; then
    .venv/bin/python shared/demo/demo_simulator.py &
    sleep 2
fi

echo "Vérification et démarrage du serveur Web SmartGas (Port $PORT)..."
if ! ss -tlpn | grep -q ":$PORT"; then
    cd web && npm run preview -- --host 0.0.0.0 --port $PORT &
    cd ..
    sleep 2
fi

echo "Lancement du tunnel Cloudflare haute disponibilité..."
./cloudflared tunnel --url http://localhost:$PORT
