#!/bin/bash
# =============================================================================
# SMART GAS - Script d'Exposition Distante (Tunnels Publics Sécurisés)
# Expose l'application Web SmartGas + API ESP32 + WebSocket pour tests distants
# =============================================================================

PORT=3000

echo "Démarrage des tunnels d'accès distant pour SMART GAS (Port $PORT)..."
echo "Appuyez sur Ctrl+C pour arrêter tous les tunnels."

cleanup() {
    echo "Arrêt des tunnels en cours..."
    kill $(jobs -p) 2>/dev/null
    exit
}
trap cleanup SIGINT SIGTERM

# 1. Localhost.run
(
    while true; do
        echo "[Localhost.run] Connexion en cours..."
        ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -R 80:localhost:$PORT nokey@localhost.run 2>&1 | tee -a /tmp/smartgas_localhost_run.log
        echo "[Localhost.run] Reconnexion dans 5s..."
        sleep 5
    done
) &

# 2. Pinggy.io
(
    while true; do
        echo "[Pinggy.io] Connexion en cours..."
        ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -R 80:localhost:$PORT a.pinggy.io 2>&1 | tee -a /tmp/smartgas_pinggy.log
        echo "[Pinggy.io] Reconnexion dans 5s..."
        sleep 5
    done
) &

# 3. Localtunnel
(
    while true; do
        echo "[Localtunnel] Connexion en cours..."
        npx --yes localtunnel --port $PORT > /tmp/smartgas_localtunnel.log 2>&1
        echo "[Localtunnel] Reconnexion dans 5s..."
        sleep 5
    done
) &

wait
