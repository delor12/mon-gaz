# SmartGas Prototype Diagnostic Tool (PowerShell Native)
# Conçu pour Windows 10 et Windows 11 (sans Python ni outil tiers requis)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "SmartGas - Diagnostic Prototype ESP32"

function Write-Banner {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  🔥 SMART GAS - OUTIL DE DIAGNOSTIC POWERSHELL POUR WINDOWS    " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-UsbSerialPorts {
    Write-Host "--- 1. PORTS SÉRIE USB DÉTECTÉS ---" -ForegroundColor Yellow
    try {
        $ports = [System.IO.Ports.SerialPort]::GetPortNames()
        if ($ports.Count -gt 0) {
            Write-Host "  ✅ $($ports.Count) port(s) COM détecté(s) :" -ForegroundColor Green
            foreach ($p in $ports) {
                Write-Host "     • $p" -ForegroundColor White
            }
        } else {
            Write-Host "  ℹ️ Aucun port COM détecté. Branchez l'ESP32 en USB si vous souhaitez le programmer." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  ℹ️ Impossible de scanner les ports COM via System.IO.Ports." -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Test-EspEndpoint($target) {
    $url = "http://$target/api/v1/data"
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 2 -ErrorAction Stop
        $sw.Stop()
        return @{
            Success = $true
            Data = $resp
            LatencyMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
            Host = $target
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Host = $target
        }
    }
}

function Show-Dashboard($info) {
    $d = $info.Data
    $hostTarget = $info.Host
    $latency = $info.LatencyMs

    Write-Host "┌─────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│  🟢 PROTOTYPE EN LIGNE SUR : $($hostTarget.PadRight(30))│" -ForegroundColor Green
    Write-Host "│  Latence Réseau : $($latency) ms".PadRight(62) + "│" -ForegroundColor Gray
    Write-Host "├─────────────────────────────────────────────────────────────┤" -ForegroundColor Cyan

    $id = if ($d.device_id) { $d.device_id } else { "ESP32-SmartGas" }
    $w = if ($d.weight_kg) { $d.weight_kg } else { 0.0 }
    $pct = if ($d.level_percent) { $d.level_percent } else { 0.0 }
    $ppm = if ($d.gas_ppm) { $d.gas_ppm } else { 0 }
    $leak = $d.leak
    $valve = if ($d.valve_state) { $d.valve_state } else { "UNKNOWN" }
    $temp = if ($d.temperature_c) { $d.temperature_c } else { 20.0 }
    $hum = if ($d.humidity_percent) { $d.humidity_percent } else { 50.0 }
    $rssi = if ($d.rssi) { $d.rssi } else { -60 }

    Write-Host "│  Identifiant : $($id.PadRight(44))│"
    Write-Host "│  Poids Gaz   : $(("{0:N2} kg ({1:N1} %)" -f $w, $pct).PadRight(44))│" -ForegroundColor Yellow

    if ($leak -eq $true) {
        Write-Host "│  Capteur Gaz : $($ppm) ppm --> 🚨 FUITE DÉTECTÉE !".PadRight(62) + "│" -ForegroundColor Red
    } else {
        Write-Host "│  Capteur Gaz : $($ppm) ppm --> ✅ Normal (Air sain)".PadRight(62) + "│" -ForegroundColor Green
    }

    if ($valve -eq "OPEN") {
        Write-Host "│  Électrovanne: OUVERTE (Passante)".PadRight(62) + "│" -ForegroundColor Green
    } else {
        Write-Host "│  Électrovanne: FERMÉE (Coupure de gaz active)".PadRight(62) + "│" -ForegroundColor Magenta
    }

    Write-Host "│  Ambiance    : $($temp) °C / $($hum) % HR".PadRight(62) + "│"
    Write-Host "│  Signal Wi-Fi: $($rssi) dBm".PadRight(62) + "│"
    Write-Host "└─────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
}

# --- DÉBUT DU PROGRAMME ---
Write-Banner
Get-UsbSerialPorts

Write-Host "--- 2. DÉTECTION DU PROTOTYPE RÉSEAU ---" -ForegroundColor Yellow
Write-Host "Test de l'adresse mDNS (smartgas.local)..." -NoNewline
$result = Test-EspEndpoint "smartgas.local"

if (-not $result.Success) {
    Write-Host " [Injoignable]" -ForegroundColor DarkGray
    Write-Host "Test du simulateur local (localhost:8080)..." -NoNewline
    $result = Test-EspEndpoint "localhost:8080"
}

if (-not $result.Success) {
    Write-Host " [Injoignable]" -ForegroundColor DarkGray
    Write-Host ""
    $manual = Read-Host "Entrez l'adresse IP de votre ESP32 (ex: 192.168.1.50) ou appuyez sur Entrée pour réessayer"
    if ($manual) {
        $result = Test-EspEndpoint $manual
    }
} else {
    Write-Host " [OK]" -ForegroundColor Green
}

if (-not $result.Success) {
    Write-Host ""
    Write-Host "❌ Impossible de se connecter au prototype ou au simulateur." -ForegroundColor Red
    Write-Host "Vérifiez que votre PC et l'ESP32 sont sur le même réseau Wi-Fi." -ForegroundColor White
    Write-Host ""
    Pause
    Exit
}

Show-Dashboard $result

# Menu interactif
$targetHost = $result.Host
while ($true) {
    Write-Host ""
    Write-Host "Actions disponibles :" -ForegroundColor Cyan
    Write-Host "  [1] Rafraîchir les valeurs"
    Write-Host "  [2] Fermer l'électrovanne (Sécurité)"
    Write-Host "  [3] Ouvrir l'électrovanne"
    Write-Host "  [4] Faire la Tare (0 kg)"
    Write-Host "  [0] Quitter"
    $c = Read-Host "Votre choix"

    if ($c -eq "0") { break }
    elseif ($c -eq "1") {
        $res = Test-EspEndpoint $targetHost
        if ($res.Success) { Show-Dashboard $res }
    }
    elseif ($c -eq "2") {
        Write-Host "Envoi fermeture vanne..." -ForegroundColor Yellow
        try {
            $body = '{"action":"CLOSE"}'
            Invoke-RestMethod -Uri "http://$targetHost/api/v1/valve/control" -Method Post -Body $body -ContentType "application/json" | Out-Null
            Write-Host "✅ Vanne fermée !" -ForegroundColor Green
        } catch { Write-Host "❌ Erreur : $($_.Exception.Message)" -ForegroundColor Red }
    }
    elseif ($c -eq "3") {
        Write-Host "Envoi ouverture vanne..." -ForegroundColor Yellow
        try {
            $body = '{"action":"OPEN"}'
            Invoke-RestMethod -Uri "http://$targetHost/api/v1/valve/control" -Method Post -Body $body -ContentType "application/json" | Out-Null
            Write-Host "✅ Vanne ouverte !" -ForegroundColor Green
        } catch { Write-Host "❌ Erreur : $($_.Exception.Message)" -ForegroundColor Red }
    }
    elseif ($c -eq "4") {
        Write-Host "Envoi commande tare (0 kg)..." -ForegroundColor Yellow
        try {
            Invoke-RestMethod -Uri "http://$targetHost/api/v1/tare" -Method Post -Body "{}" -ContentType "application/json" | Out-Null
            Write-Host "✅ Tare enregistrée !" -ForegroundColor Green
        } catch { Write-Host "❌ Erreur : $($_.Exception.Message)" -ForegroundColor Red }
    }
}
