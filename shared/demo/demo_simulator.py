#!/usr/bin/env python3
"""
SmartGas Device Simulator (ESP32 Mock Server)
Permet de simuler intégralement le matériel ESP32 (HTTP REST, WebSocket, MQTT)
pour tester les applications Mobile (Flutter) et Web (React) sans prototype physique.
"""

import sys
import time
import json
import asyncio
from datetime import datetime, timezone
from aiohttp import web

HOST = "0.0.0.0"
PORT = 8080

# État simulé
device_state = {
    "device_id": "SIMULATOR-SMARTGAS-8A4F",
    "weight_kg": 8.420,
    "gross_weight_kg": 21.420,
    "level_percent": 67.36,
    "gas_ppm": 145,
    "leak": False,
    "temperature_c": 21.8,
    "humidity_percent": 48.5,
    "valve_state": "OPEN",
    "buzzer_muted": False,
    "sensor_fault": False,
    "rssi": -58,
    "uptime_s": 100,
    "firmware": "1.0.0-SIM",
    "timestamp": int(datetime.now(timezone.utc).timestamp()),
}

ws_clients = set()

# --- ROUTES REST ---
async def handle_data(request):
    device_state["timestamp"] = int(datetime.now(timezone.utc).timestamp())
    return web.json_response(device_state)

async def handle_history(request):
    now = int(datetime.now(timezone.utc).timestamp())
    points = []
    base_w = 8.540
    for i in range(12, 0, -1):
        points.append({
            "timestamp": now - (i * 3600),
            "weight_kg": round(base_w - (0.025 * (12 - i)), 3),
            "consumption_kg": 0.025
        })
    return web.json_response({
        "range": request.query.get("range", "day"),
        "resolution": request.query.get("resolution", "hour"),
        "count": len(points),
        "points": points
    })

async def handle_tare(request):
    device_state["gross_weight_kg"] = 0.0
    device_state["weight_kg"] = 0.0
    device_state["level_percent"] = 0.0
    return web.json_response({"success": True, "tare_offset": 8412530, "message": "Tare effectuée"})

async def handle_calibrate(request):
    body = await request.json()
    known = body.get("known_weight_kg", 5.0)
    device_state["weight_kg"] = known
    device_state["gross_weight_kg"] = known + 13.0
    device_state["level_percent"] = (known / 12.5) * 100.0
    return web.json_response({"success": True, "calibration_factor": -22450.5, "measured_weight_kg": known})

async def handle_valve(request):
    body = await request.json()
    action = body.get("action")
    if action == "OPEN" and device_state["leak"]:
        return web.json_response({
            "code": "LEAK_ACTIVE_VALVE_LOCKED",
            "message": "Action refusée : fuite de gaz active."
        }, status=403)
    
    device_state["valve_state"] = "OPEN" if action == "OPEN" else "CLOSED"
    return web.json_response({"valve_state": device_state["valve_state"], "auto_cutoff_active": False})

async def handle_mute(request):
    device_state["buzzer_muted"] = True
    return web.json_response({"muted": True, "mute_remaining_seconds": 120})

async def handle_pair(request):
    return web.json_response({
        "token": "sg_sec_simulated_test_token_2026",
        "device_id": device_state["device_id"],
        "expires_in_days": 365
    })

# --- WEBSOCKET ---
async def handle_ws(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    ws_clients.add(ws)
    print(f"[WS] Client connecté ({len(ws_clients)} clients actifs)")

    try:
        async for msg in ws:
            if msg.type == web.WSMsgType.TEXT:
                if "ping" in msg.data:
                    await ws.send_str('{"type":"pong"}')
    finally:
        ws_clients.remove(ws)
        print(f"[WS] Client déconnecté ({len(ws_clients)} restants)")
    return ws

# --- BROADCAST LOOP (1 Hz) ---
async def broadcast_loop():
    while True:
        await asyncio.sleep(1.0)
        device_state["uptime_s"] += 1
        device_state["timestamp"] = int(datetime.now(timezone.utc).timestamp())

        # Légère décroissance naturelle si nominal
        if not device_state["leak"] and device_state["weight_kg"] > 0.1:
            device_state["weight_kg"] = round(device_state["weight_kg"] - 0.00005, 4)
            device_state["level_percent"] = round((device_state["weight_kg"] / 12.5) * 100.0, 1)

        payload = json.dumps({"type": "telemetry", "data": device_state})
        for ws in list(ws_clients):
            try:
                await ws.send_str(payload)
            except Exception:
                pass

def set_scenario(scenario_idx: int):
    if scenario_idx == 1: # Nominal
        device_state["weight_kg"] = 8.420
        device_state["gross_weight_kg"] = 21.420
        device_state["level_percent"] = 67.36
        device_state["gas_ppm"] = 145
        device_state["leak"] = False
        device_state["valve_state"] = "OPEN"
        print("[SCÉNARIO] 1. État nominal activé (67%, 145 ppm, vanne ouverte)")
    elif scenario_idx == 2: # Fuite de gaz
        device_state["gas_ppm"] = 850
        device_state["leak"] = True
        device_state["valve_state"] = "CLOSED"
        print("[SCÉNARIO] 2. 🚨 ALERTE FUITE DE GAZ ACTIVÉE (850 ppm, vanne fermée)")
    elif scenario_idx == 3: # Niveau bas
        device_state["weight_kg"] = 1.450
        device_state["gross_weight_kg"] = 14.450
        device_state["level_percent"] = 11.6
        device_state["gas_ppm"] = 110
        device_state["leak"] = False
        print("[SCÉNARIO] 3. Niveau bas activé (11.6%, 1.45 kg)")
    elif scenario_idx == 4: # Changement de bouteille
        device_state["weight_kg"] = 12.500
        device_state["gross_weight_kg"] = 25.500
        device_state["level_percent"] = 100.0
        print("[SCÉNARIO] 4. Nouvelle bouteille pleine installée (100%, 12.5 kg)")

async def init_app():
    app = web.Application()
    
    # CORS Headers middleware
    @web.middleware
    async def cors_middleware(request, handler):
        if request.method == "OPTIONS":
            resp = web.Response()
        else:
            resp = await handler(request)
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        return resp

    app.middlewares.append(cors_middleware)

    app.router.add_get("/api/v1/data", handle_data)
    app.router.add_get("/api/v1/history", handle_history)
    app.router.add_post("/api/v1/tare", handle_tare)
    app.router.add_post("/api/v1/calibrate", handle_calibrate)
    app.router.add_post("/api/v1/valve/control", handle_valve)
    app.router.add_post("/api/v1/alarm/mute", handle_mute)
    app.router.add_post("/api/v1/auth/pair", handle_pair)
    app.router.add_get("/ws", handle_ws)

    return app

def main():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    app = loop.run_until_complete(init_app())
    loop.create_task(broadcast_loop())

    print("==================================================")
    print(f"  SMART GAS DEVICE SIMULATOR ACTIF SUR PORT {PORT}")
    print("==================================================")
    print(f"  REST API  : http://localhost:{PORT}/api/v1/data")
    print(f"  WebSocket : ws://localhost:{PORT}/ws")
    print("--------------------------------------------------")
    print("  Commandes directes pour piloter la simulation :")
    print("  [1] Nominal (67%)")
    print("  [2] Fuite de gaz (850 ppm + vanne coupée)")
    print("  [3] Niveau bas (11%)")
    print("  [4] Remplacement bouteille (+12.5 kg)")
    print("==================================================")

    web.run_app(app, host=HOST, port=PORT)

if __name__ == "__main__":
    main()
