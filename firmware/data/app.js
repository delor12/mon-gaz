// SMART GAS - Client Web Embarqué LittleFS
let ws = null;
let reconnectTimer = null;
let currentValveState = 'OPEN';
let authToken = localStorage.getItem('sg_token') || 'sg_sec_default_dev_token';

// Synthétiseur Audio Web Audio API pour sirène d'alerte locale
let audioCtx = null;
let alarmOscillator = null;

function initAudio() {
    if (!audioCtx) {
        audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
}

function playAlarmSound() {
    try {
        initAudio();
        if (alarmOscillator) return;
        alarmOscillator = audioCtx.createOscillator();
        const gainNode = audioCtx.createGain();
        alarmOscillator.type = 'sawtooth';
        alarmOscillator.frequency.setValueAtTime(800, audioCtx.currentTime);
        alarmOscillator.frequency.exponentialRampToValueAtTime(1600, audioCtx.currentTime + 0.3);
        alarmOscillator.connect(gainNode);
        gainNode.connect(audioCtx.destination);
        alarmOscillator.start();
        setTimeout(() => {
            if (alarmOscillator) {
                alarmOscillator.stop();
                alarmOscillator.disconnect();
                alarmOscillator = null;
            }
        }, 300);
    } catch (e) {
        console.warn('Web Audio bloqué avant interaction:', e);
    }
}

function connectWebSocket() {
    const host = window.location.host || 'smartgas.local';
    const wsUrl = `ws://${host}/ws`;

    ws = new WebSocket(wsUrl);

    ws.onopen = () => {
        console.log('[WS] Connecté à l\'ESP32');
        const pill = document.getElementById('conn-pill');
        pill.textContent = 'En ligne (LAN)';
        pill.className = 'status-pill online';
    };

    ws.onmessage = (event) => {
        try {
            const msg = JSON.parse(event.data);
            if (msg.type === 'telemetry') {
                updateUI(msg.data);
            } else if (msg.type === 'event') {
                handleEvent(msg);
            }
        } catch (e) {
            console.error('Erreur parsing WS:', e);
        }
    };

    ws.onclose = () => {
        console.warn('[WS] Déconnecté. Reconnexion dans 2s...');
        const pill = document.getElementById('conn-pill');
        pill.textContent = 'Déconnecté';
        pill.className = 'status-pill offline';
        clearTimeout(reconnectTimer);
        reconnectTimer = setTimeout(connectWebSocket, 2000);
    };

    ws.onerror = (err) => {
        console.error('[WS] Erreur réseau:', err);
        ws.close();
    };
}

function updateUI(data) {
    // 1. Mise à jour de la jauge circulaire
    const pct = Math.max(0, Math.min(100, data.level_percent || 0));
    document.getElementById('txt-level-percent').textContent = `${pct.toFixed(1)} %`;
    document.getElementById('txt-net-weight').textContent = `${(data.weight_kg || 0).toFixed(2)} kg`;

    const circumference = 534; // 2 * PI * 85
    const offset = circumference - (pct / 100) * circumference;
    const gaugeFill = document.getElementById('gauge-fill');
    gaugeFill.style.strokeDashoffset = offset;

    // Changement de couleur dynamique selon le niveau
    if (pct <= 5) {
        gaugeFill.style.stroke = '#E5383B';
    } else if (pct <= 15) {
        gaugeFill.style.stroke = '#FFD60A';
    } else {
        gaugeFill.style.stroke = '#D4AF37';
    }

    // 2. Métriques
    document.getElementById('txt-gross-weight').textContent = `${(data.gross_weight_kg || 0).toFixed(2)} kg`;
    document.getElementById('txt-gas-ppm').textContent = `${data.gas_ppm || 0} ppm`;
    document.getElementById('txt-temp').textContent = `${(data.temperature_c || 20).toFixed(1)} °C`;
    document.getElementById('txt-uptime').textContent = `Uptime: ${data.uptime_s || 0} s`;

    currentValveState = data.valve_state || 'OPEN';
    const valveBtn = document.getElementById('btn-toggle-valve');
    const valveText = document.getElementById('txt-valve-state');

    if (currentValveState === 'OPEN') {
        valveText.textContent = 'OUVERTE';
        valveText.style.color = '#10B981';
        valveBtn.textContent = 'Fermer Électrovanne';
        valveBtn.className = 'btn btn-primary';
    } else {
        valveText.textContent = 'FERMÉE';
        valveText.style.color = '#E5383B';
        valveBtn.textContent = 'Ouvrir Électrovanne';
        valveBtn.className = 'btn btn-secondary';
    }

    // 3. Gestion de l'alerte fuite
    const alertBanner = document.getElementById('alert-banner');
    if (data.leak) {
        alertBanner.classList.remove('hidden');
        playAlarmSound();
    } else {
        alertBanner.classList.add('hidden');
    }
}

function handleEvent(eventMsg) {
    console.log('[EVENT]', eventMsg);
    if (eventMsg.event === 'leak_critical') {
        alert('ALERTE CRITIQUE : FUITE DE GAZ DÉTECTÉE PAR L\'ESP32 !');
    } else if (eventMsg.event === 'bottle_replaced') {
        alert('Nouvelle bouteille de gaz pleine détectée !');
    }
}

// Actions utilisateur
document.getElementById('btn-tare').addEventListener('click', async () => {
    if (!confirm('Assurez-vous que le plateau est vide. Confirmer la tare ?')) return;
    try {
        const res = await fetch('/api/v1/tare', {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        const json = await res.json();
        if (res.ok) alert('Tare effectuée avec succès !');
        else alert(`Erreur: ${json.message}`);
    } catch (e) {
        alert('Erreur communication avec le boîtier');
    }
});

document.getElementById('btn-toggle-valve').addEventListener('click', async () => {
    const newAction = (currentValveState === 'OPEN') ? 'CLOSE' : 'OPEN';
    try {
        const res = await fetch('/api/v1/valve/control', {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}` 
            },
            body: JSON.stringify({ action: newAction })
        });
        const json = await res.json();
        if (!res.ok) alert(`Erreur: ${json.message}`);
    } catch (e) {
        alert('Erreur communication');
    }
});

document.getElementById('btn-mute-alarm').addEventListener('click', async () => {
    try {
        await fetch('/api/v1/alarm/mute', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ duration_seconds: 120 })
        });
        alert('Buzzer mis en sourdine pour 120 secondes.');
    } catch (e) {
        console.error(e);
    }
});

document.getElementById('btn-save-cfg').addEventListener('click', async () => {
    const capacity = parseFloat(document.getElementById('input-cap-kg').value);
    const tare = parseFloat(document.getElementById('input-tare-kg').value);
    const leakPpm = parseInt(document.getElementById('input-leak-ppm').value);

    try {
        const res = await fetch('/api/v1/config', {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
            },
            body: JSON.stringify({
                capacity_kg: capacity,
                tare_weight_kg: tare,
                leak_threshold_ppm: leakPpm
            })
        });
        const json = await res.json();
        if (res.ok) alert('Configuration enregistrée en NVS !');
        else alert(`Erreur: ${json.message}`);
    } catch (e) {
        alert('Erreur sauvegarde');
    }
});

// Démarrage initial
window.addEventListener('DOMContentLoaded', () => {
    connectWebSocket();
});
