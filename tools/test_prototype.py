#!/usr/bin/env python3
"""
SmartGas Prototype Connectivity & Diagnostic Tool
Compatible Windows, Linux et macOS sans dépendance externe requise (bibliothèque standard).
Permet de diagnostiquer la liaison USB Série et Wi-Fi avec le boîtier physique ESP32.
"""

import sys
import os
import time
import json
import socket
import platform
import subprocess
import urllib.request
import urllib.error

def print_header(title):
    print("\n" + "=" * 65)
    print(f"  {title}")
    print("=" * 65)

def get_windows_com_ports():
    """Détecte les ports COM disponibles sous Windows sans dépendance pyserial."""
    ports = []
    if platform.system() == "Windows":
        try:
            import winreg
            key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DEVICEMAP\SERIALCOMM")
            for i in range(256):
                try:
                    val_name, port_name, _ = winreg.EnumValue(key, i)
                    ports.append((port_name, val_name))
                except OSError:
                    break
            winreg.CloseKey(key)
        except Exception:
            # Fallback PowerShell
            try:
                cmd = ["powershell", "-NoProfile", "-Command", "[System.IO.Ports.SerialPort]::GetPortNames()"]
                res = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
                for line in res.stdout.splitlines():
                    p = line.strip()
                    if p:
                        ports.append((p, "Port Série"))
            except Exception:
                pass
    else:
        # Linux / macOS
        dev_dir = "/dev"
        if os.path.exists(dev_dir):
            for fname in os.listdir(dev_dir):
                if fname.startswith("ttyUSB") or fname.startswith("ttyACM") or fname.startswith("cu.usbserial"):
                    ports.append((f"/dev/{fname}", "USB Serial"))
    return ports

def test_http_endpoint(host, path="/api/v1/data", timeout=2.0):
    url = f"http://{host}{path}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "SmartGas-Diagnostic/1.0", "Accept": "application/json"}
    )
    try:
        t0 = time.time()
        with urllib.request.urlopen(req, timeout=timeout) as response:
            dt_ms = round((time.time() - t0) * 1000, 1)
            raw = response.read().decode("utf-8")
            data = json.loads(raw)
            return True, data, dt_ms, None
    except urllib.error.HTTPError as e:
        return False, None, 0, f"Erreur HTTP {e.code}: {e.reason}"
    except urllib.error.URLError as e:
        return False, None, 0, f"Injoignable ({e.reason})"
    except Exception as e:
        return False, None, 0, str(e)

def send_http_post(host, path, payload, timeout=3.0):
    url = f"http://{host}{path}"
    data_bytes = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data_bytes,
        headers={"Content-Type": "application/json", "User-Agent": "SmartGas-Diagnostic/1.0"}
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
            return True, json.loads(raw) if raw else {"status": "ok"}, None
    except Exception as e:
        return False, None, str(e)

def scan_local_network_for_smartgas():
    """Tente de repérer l'ESP32 sur le réseau local via mDNS et scan rapide."""
    print("  [*] Recherche automatique du prototype ESP32...")
    
    # 1. mDNS test
    targets = ["smartgas.local", "localhost:8080", "127.0.0.1:8080"]
    for target in targets:
        print(f"      - Test mDNS / Local : http://{target}/api/v1/data ... ", end="", flush=True)
        ok, data, dt, err = test_http_endpoint(target, timeout=1.5)
        if ok:
            print(f"SUCCÈS ({dt} ms)")
            return target, data
        else:
            print("Non répondu")

    # 2. Détection de l'IP de la machine locale pour dériver le sous-réseau
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        parts = local_ip.split(".")
        if len(parts) == 4 and parts[0] in ("192", "10", "172"):
            subnet_prefix = ".".join(parts[:3])
            print(f"  [*] Détection du sous-réseau local : {subnet_prefix}.x")
            print("      (Astuce: si votre ESP32 a une IP fixe ou connue, entrez-la manuellement)")
    except Exception:
        pass

    return None, None

def display_telemetry(data, host, latency_ms):
    print("\n" + "┌" + "─" * 63 + "┐")
    print(f"│  🟢 PROTOTYPE SMARTGAS EN LIGNE SUR : {host:<30}│")
    print(f"│  Temps de réponse réseau : {latency_ms} ms" + " " * (35 - len(str(latency_ms))) + "│")
    print("├" + "─" * 63 + "┤")
    
    device_id = data.get("device_id", "Inconnu")
    weight = data.get("weight_kg", 0.0)
    level = data.get("level_percent", 0.0)
    ppm = data.get("gas_ppm", 0)
    leak = data.get("leak", False)
    valve = data.get("valve_state", "UNKNOWN")
    temp = data.get("temperature_c", 0.0)
    hum = data.get("humidity_percent", 0.0)
    rssi = data.get("rssi", -100)
    fw = data.get("firmware", "v1.0")

    leak_str = "🚨 ALERTE FUITE DE GAZ !" if leak else "✅ Normal (Aucune fuite)"
    valve_str = "OUVERTE (Gaz passant)" if valve == "OPEN" else "FERMÉE (Sécurité activée)"

    print(f"│  Identifiant Boîtier  : {device_id:<41}│")
    print(f"│  Version Firmware     : {fw:<41}│")
    print(f"│  Masse de gaz restant : {weight:.2f} kg ({level:.1f} %)" + " " * (36 - len(f"{weight:.2f} kg ({level:.1f} %)")) + "│")
    print(f"│  Capteur de Gaz MQ-6  : {ppm} ppm  --> {leak_str:<26}│")
    print(f"│  Électrovanne         : {valve_str:<41}│")
    print(f"│  Température / Humid. : {temp} °C / {hum} %" + " " * (38 - len(f"{temp} °C / {hum} %")) + "│")
    print(f"│  Signal Wi-Fi (RSSI)  : {rssi} dBm" + " " * (42 - len(f"{rssi} dBm")) + "│")
    print("└" + "─" * 63 + "┘")

def interactive_menu(host):
    while True:
        print("\n--- ACTIONS DE TEST SUR LE PROTOTYPE ---")
        print("  [1] Rafraîchir les métriques en direct (Télémétrie)")
        print("  [2] Tester l'Électrovanne : FERMER (Coupure de gaz)")
        print("  [3] Tester l'Électrovanne : OUVRIR (Rétablissement)")
        print("  [4] Effectuer la Tare du plateau (Remise à 0.00 kg)")
        print("  [5] Tester le Buzzer d'alarme (Bip / Silence)")
        print("  [6] Tester l'Appairage avec un code PIN")
        print("  [7] Changer d'adresse IP")
        print("  [0] Quitter")
        
        try:
            choice = input("\nVotre choix [0-7] : ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nFin du test.")
            break

        if choice == "0":
            break
        elif choice == "1":
            ok, data, dt, err = test_http_endpoint(host)
            if ok:
                display_telemetry(data, host, dt)
            else:
                print(f"❌ Erreur lors de la lecture : {err}")
        elif choice == "2":
            print("  [*] Envoi de la commande : FERMETURE ÉLECTROVANNE...")
            ok, resp, err = send_http_post(host, "/api/v1/valve/control", {"action": "CLOSE"})
            if ok:
                print("  ✅ Réponse reçue : Vanne fermée avec succès ! (Écoutez le déclic du relais)")
            else:
                print(f"  ❌ Échec de la commande : {err}")
        elif choice == "3":
            print("  [*] Envoi de la commande : OUVERTURE ÉLECTROVANNE...")
            ok, resp, err = send_http_post(host, "/api/v1/valve/control", {"action": "OPEN"})
            if ok:
                print("  ✅ Réponse reçue : Vanne rouverte avec succès !")
            else:
                print(f"  ❌ Échec de la commande : {err}")
        elif choice == "4":
            print("  [*] Envoi de la commande : TARE DU PLATEAU (0 kg)...")
            ok, resp, err = send_http_post(host, "/api/v1/tare", {})
            if ok:
                print("  ✅ Plateau taré à 0.00 kg (persisté dans la NVS de l'ESP32) !")
            else:
                print(f"  ❌ Échec du tarage : {err}")
        elif choice == "5":
            print("  [*] Envoi de la commande : Bip / Silence Alarme...")
            ok, resp, err = send_http_post(host, "/api/v1/alarm/mute", {"duration_s": 30})
            if ok:
                print("  ✅ Commande alarme validée.")
            else:
                print(f"  ❌ Échec : {err}")
        elif choice == "6":
            pin = input("Entrez le code PIN à 6 chiffres affiché sur l'écran TFT : ").strip()
            ok, resp, err = send_http_post(host, "/api/v1/auth/pair", {"pin": pin, "device_name": "Windows-PC-Diagnostic"})
            if ok:
                print(f"  🎉 APPAIRAGE RÉUSSI ! Token reçu : {resp.get('token', 'OK')[:16]}...")
            else:
                print(f"  ❌ Code PIN incorrect ou expiré : {err}")
        elif choice == "7":
            new_ip = input("Entrez la nouvelle adresse IP (ex: 192.168.1.50) : ").strip()
            if new_ip:
                host = new_ip
                print(f"  [*] Cible mise à jour : {host}")

def main():
    print_header("OUTIL DE DIAGNOSTIC ET TEST PROTOTYPE SMARTGAS (WINDOWS & MULTI-OS)")
    print(f"  Système d'exploitation détecté : {platform.system()} {platform.release()}")
    print(f"  Python : {platform.python_version()}")

    # 1. Vérification des ports séries / USB
    print("\n--- 1. VÉRIFICATION DES PORTS SÉRIES USB (ESP32) ---")
    ports = get_windows_com_ports()
    if ports:
        print(f"  ✅ {len(ports)} port(s) série détecté(s) sur cette machine :")
        for p, desc in ports:
            print(f"      • {p} ({desc})")
        print("  💡 Si votre ESP32 est branché en USB, son port est listé ci-dessus.")
    else:
        print("  ℹ️ Aucun port série actif détecté pour le moment.")
        print("     -> Si l'ESP32 est branché en USB, vérifiez que le pilote CH340 ou CP210x est installé.")

    # 2. Vérification de la liaison Réseau Wi-Fi / REST API
    print("\n--- 2. VÉRIFICATION DE LA LIAISON RÉSEAU (ESP32 WI-FI / LAN) ---")
    if len(sys.argv) > 1 and sys.argv[1].strip():
        host = sys.argv[1].strip()
        print(f"  [*] Cible spécifiée en paramètre : {host}")
        ok, data, dt, err = test_http_endpoint(host)
        if not ok:
            print(f"  ❌ Impossible de joindre http://{host}/api/v1/data ({err})")
            host = None
    else:
        host, data = scan_local_network_for_smartgas()

    if not host:
        print("\n  ⚠️ Détection automatique par mDNS (smartgas.local) non immédiate.")
        print("  Veuillez entrer manuellement l'adresse IP de votre prototype ESP32")
        print("  (ou appuyez sur ENTRÉE pour tester le simulateur local 'localhost:8080') :")
        try:
            manual = input("  Adresse IP ou 'smartgas.local' [défaut: localhost:8080] : ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nSortie.")
            return

        host = manual if manual else "localhost:8080"
        ok, data, dt, err = test_http_endpoint(host)
        if not ok:
            print(f"\n  ❌ Impossible de joindre http://{host}/api/v1/data")
            print(f"     Détail : {err}")
            print("\n  Conseils :")
            print("  1. Assurez-vous que l'ESP32 et ce PC Windows sont sur la même box Wi-Fi (2.4 GHz).")
            print("  2. Vérifiez l'adresse IP affichée sur la console série ou le moniteur TFT.")
            print("  3. Si vous testez sans matériel, lancez d'abord le simulateur avec 'python shared/demo/demo_simulator.py'.")
            return
        else:
            display_telemetry(data, host, dt)
    else:
        ok, data, dt, _ = test_http_endpoint(host)
        display_telemetry(data, host, dt)

    # 3. Menu interactif
    interactive_menu(host)

if __name__ == "__main__":
    main()
