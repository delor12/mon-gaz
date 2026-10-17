const { app, BrowserWindow, Menu, Tray, ipcMain, Notification, shell, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { WebSocketServer, WebSocket } = require('ws');

let mainWindow = null;
let tray = null;
let isQuitting = false;
let server = null;
let wss = null;
let serverPort = 0;

// État de simulation intégré
let simulatedState = {
  device_id: 'SMARTGAS-ESP32-8A4F',
  weight_kg: 8.420,
  gross_weight_kg: 21.420,
  level_percent: 67.36,
  gas_ppm: 145,
  leak: false,
  temperature_c: 21.8,
  humidity_percent: 48.5,
  valve_state: 'OPEN',
  buzzer_muted: false,
  sensor_fault: false,
  rssi: -58,
  uptime_s: 120,
  firmware: '1.0.0-DESKTOP',
  timestamp: Math.floor(Date.now() / 1000)
};

let activeTargetEspHost = null; // Si défini, proxy vers ESP32 physique

// Sécurité : instance unique
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  });
}

function getIconPath() {
  const icoPath = path.join(__dirname, 'assets', 'icon.ico');
  const pngPath = path.join(__dirname, 'assets', 'icon.png');
  if (process.platform === 'win32' && fs.existsSync(icoPath)) {
    return icoPath;
  }
  return pngPath;
}

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.webmanifest': 'application/manifest+json'
};

function startEmbeddedServer(callback) {
  const webDir = path.join(__dirname, 'web-dist');

  server = http.createServer((req, res) => {
    // En-têtes CORS universels
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
      res.writeHead(200);
      res.end();
      return;
    }

    const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
    const pathname = parsedUrl.pathname;

    // --- API REST ---
    if (pathname.startsWith('/api/v1/')) {
      handleApiRequest(pathname, req, res);
      return;
    }

    // --- FICHIERS STATIQUES (React Web App) ---
    let relativePath = pathname === '/' ? 'index.html' : pathname.replace(/^\//, '');
    let filePath = path.join(webDir, relativePath);

    // Sécurité chemin
    if (!filePath.startsWith(webDir)) {
      res.writeHead(403);
      res.end('Accès interdit');
      return;
    }

    // Fallback SPA vers index.html si fichier inexistant
    if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
      filePath = path.join(webDir, 'index.html');
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, content) => {
      if (err) {
        res.writeHead(500);
        res.end(`Erreur serveur : ${err.message}`);
      } else {
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(content);
      }
    });
  });

  // WebSocket Server sur le même serveur HTTP
  wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', (ws) => {
    // Envoi immédiat des données courantes
    const payload = JSON.stringify({ type: 'telemetry', data: simulatedState });
    ws.send(payload);

    ws.on('message', (msg) => {
      try {
        if (msg.toString().includes('ping')) {
          ws.send(JSON.stringify({ type: 'pong' }));
        }
      } catch (e) {}
    });
  });

  // Boucle de broadcast WebSocket à 1 Hz
  setInterval(() => {
    simulatedState.uptime_s += 1;
    simulatedState.timestamp = Math.floor(Date.now() / 1000);

    // Décroissance subtile si nominal
    if (!simulatedState.leak && simulatedState.weight_kg > 0.1) {
      simulatedState.weight_kg = Math.round((simulatedState.weight_kg - 0.00005) * 10000) / 10000;
      simulatedState.level_percent = Math.round(((simulatedState.weight_kg / 12.5) * 100.0) * 10) / 10;
    }

    const broadcastData = JSON.stringify({ type: 'telemetry', data: simulatedState });
    wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(broadcastData);
      }
    });
  }, 1000);

  server.listen(0, '127.0.0.1', () => {
    serverPort = server.address().port;
    console.log(`[SmartGas Desktop] Serveur embarqué actif sur http://127.0.0.1:${serverPort}`);
    callback(serverPort);
  });
}

function handleApiRequest(pathname, req, res) {
  // Proxy vers ESP32 réel si configuré
  if (activeTargetEspHost) {
    const targetUrl = `http://${activeTargetEspHost}${req.url}`;
    const proxyReq = http.request(targetUrl, {
      method: req.method,
      headers: { ...req.headers, host: activeTargetEspHost }
    }, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    });
    proxyReq.on('error', () => {
      // Fallback sur le simulateur si l'ESP32 ne répond pas
      serveSimulatedApi(pathname, req, res);
    });
    req.pipe(proxyReq);
    return;
  }

  serveSimulatedApi(pathname, req, res);
}

function serveSimulatedApi(pathname, req, res) {
  res.setHeader('Content-Type', 'application/json');

  if (pathname === '/api/v1/data') {
    simulatedState.timestamp = Math.floor(Date.now() / 1000);
    res.writeHead(200);
    res.end(JSON.stringify(simulatedState));
  } else if (pathname === '/api/v1/history') {
    const now = Math.floor(Date.now() / 1000);
    const points = [];
    const baseW = 8.54;
    for (let i = 12; i >= 0; i--) {
      points.push({
        timestamp: now - (i * 3600),
        weight_kg: Math.round((baseW - (0.02 * (12 - i))) * 1000) / 1000,
        consumption_kg: 0.02
      });
    }
    res.writeHead(200);
    res.end(JSON.stringify({ range: 'day', resolution: 'hour', count: points.length, points }));
  } else if (pathname === '/api/v1/tare' && req.method === 'POST') {
    simulatedState.weight_kg = 0.000;
    simulatedState.level_percent = 0.0;
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'ok', tare_offset: 458920, message: 'Tare effectuée' }));
  } else if (pathname === '/api/v1/valve/control' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const parsed = JSON.parse(body || '{}');
        const nextState = parsed.action === 'OPEN' ? 'OPEN' : 'CLOSED';
        simulatedState.valve_state = nextState;
        res.writeHead(200);
        res.end(JSON.stringify({ status: 'ok', valve_state: nextState }));
      } catch (e) {
        res.writeHead(400);
        res.end(JSON.stringify({ error: 'Payload invalide' }));
      }
    });
  } else if (pathname === '/api/v1/alarm/mute' && req.method === 'POST') {
    simulatedState.buzzer_muted = true;
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'ok', buzzer_muted: true }));
  } else if (pathname === '/api/v1/auth/pair' && req.method === 'POST') {
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'paired', token: 'sg_bearer_desktop_session_token_ok', expires_in: 86400 }));
  } else {
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Endpoint non trouvé' }));
  }
}

function setScenario(scenario) {
  if (scenario === 'nominal') {
    simulatedState.weight_kg = 8.420;
    simulatedState.level_percent = 67.36;
    simulatedState.gas_ppm = 145;
    simulatedState.leak = false;
    simulatedState.valve_state = 'OPEN';
  } else if (scenario === 'leak') {
    simulatedState.gas_ppm = 850;
    simulatedState.leak = true;
    simulatedState.valve_state = 'CLOSED';
    if (Notification.isSupported()) {
      new Notification({
        title: '🚨 SMART GAS : ALERTE FUITE DE GAZ !',
        body: 'Concentration élevée détectée (850 ppm). Électrovanne coupée automatiquement.',
        icon: getIconPath()
      }).show();
    }
  } else if (scenario === 'low') {
    simulatedState.weight_kg = 1.450;
    simulatedState.level_percent = 11.6;
    simulatedState.gas_ppm = 120;
    simulatedState.leak = false;
  }
}

function createWindow(port) {
  const icon = getIconPath();

  mainWindow = new BrowserWindow({
    width: 1280,
    height: 850,
    minWidth: 980,
    minHeight: 680,
    title: 'SMART GAS - Moniteur Intelligent de Bouteille de Gaz GPL',
    backgroundColor: '#061A45',
    icon: icon,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: false,
      webSecurity: false
    }
  });

  // Construction du menu natif
  const templateMenu = [
    {
      label: 'Fichier',
      submenu: [
        {
          label: 'Recharger l\'interface',
          accelerator: 'CmdOrCtrl+R',
          click: () => mainWindow.reload()
        },
        {
          label: 'Mode Plein Écran',
          accelerator: 'F11',
          click: () => mainWindow.setFullScreen(!mainWindow.isFullScreen())
        },
        { type: 'separator' },
        {
          label: 'Quitter SMART GAS',
          accelerator: 'CmdOrCtrl+Q',
          click: () => {
            isQuitting = true;
            app.quit();
          }
        }
      ]
    },
    {
      label: 'Scénarios & Démo',
      submenu: [
        {
          label: '🟢 Scénario Nominal (8.42 kg - 67%)',
          click: () => setScenario('nominal')
        },
        {
          label: '🚨 Simuler Fuite de Gaz (850 ppm - Coupure Vanne)',
          click: () => setScenario('leak')
        },
        {
          label: '🟡 Scénario Niveau Bas (1.45 kg - 11%)',
          click: () => setScenario('low')
        }
      ]
    },
    {
      label: 'ESP32 & Réseau',
      submenu: [
        {
          label: 'Utiliser Simulateur Embarqué Local',
          click: () => {
            activeTargetEspHost = null;
            dialog.showMessageBox(mainWindow, {
              type: 'info',
              title: 'Mode Simulateur',
              message: 'L\'application est maintenant connectée au simulateur embarqué local.'
            });
            mainWindow.reload();
          }
        },
        {
          label: 'Connecter au Prototype Réel (IP)...',
          click: async () => {
            // Note: prompt direct via executeJavaScript dans la WebUI
            mainWindow.webContents.executeJavaScript(`
              const ip = prompt("Entrez l'adresse IP de votre prototype ESP32 (ex: 192.168.1.192 ou smartgas.local) :", localStorage.getItem('sg_device_host') || '192.168.1.192');
              if (ip) {
                localStorage.setItem('sg_device_host', ip);
                window.location.reload();
              }
            `);
          }
        }
      ]
    },
    {
      label: 'Outils',
      submenu: [
        {
          label: 'Outils de Développement (Console)',
          accelerator: 'Ctrl+Shift+I',
          click: () => mainWindow.webContents.toggleDevTools()
        }
      ]
    },
    {
      label: 'Aide',
      submenu: [
        {
          label: 'Dépôt GitHub du Projet',
          click: () => shell.openExternal('https://github.com/delor12/mon-gaz')
        },
        {
          label: 'À propos de SmartGas',
          click: () => {
            dialog.showMessageBox(mainWindow, {
              type: 'info',
              title: 'À propos de SmartGas Desktop',
              message: 'SMART GAS Desktop v1.0.0 (Windows x64)',
              detail: 'Système intelligent de surveillance de bouteille de gaz GPL avec coupure autonome et télémétrie en temps réel.\nLicence MIT.'
            });
          }
        }
      ]
    }
  ];

  const menu = Menu.buildFromTemplate(templateMenu);
  Menu.setApplicationMenu(menu);

  // Chargement direct via le serveur HTTP embarqué
  mainWindow.loadURL(`http://127.0.0.1:${port}`);

  // Interception de la fermeture pour minimiser dans le Tray
  mainWindow.on('close', (event) => {
    if (!isQuitting) {
      event.preventDefault();
      mainWindow.hide();
      if (tray && process.platform === 'win32') {
        tray.displayBalloon({
          iconType: 'info',
          title: 'SMART GAS actif en arrière-plan',
          content: 'La surveillance de votre bouteille de gaz continue dans la zone de notification.'
        });
      }
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function createTray() {
  const icon = getIconPath();
  try {
    tray = new Tray(icon);
    const contextMenu = Menu.buildFromTemplate([
      {
        label: 'Ouvrir SMART GAS',
        click: () => {
          if (mainWindow) {
            mainWindow.show();
            mainWindow.focus();
          }
        }
      },
      { type: 'separator' },
      {
        label: 'État Surveillance : ACTIF (10 Hz)',
        enabled: false
      },
      { type: 'separator' },
      {
        label: 'Quitter Définitivement',
        click: () => {
          isQuitting = true;
          app.quit();
        }
      }
    ]);

    tray.setToolTip('SMART GAS - Surveillance Bouteille de Gaz GPL (Actif)');
    tray.setContextMenu(contextMenu);

    tray.on('double-click', () => {
      if (mainWindow) {
        mainWindow.show();
        mainWindow.focus();
      }
    });
  } catch (err) {
    console.warn('Impossible d\'initialiser le Tray :', err.message);
  }
}

// Gestion des notifications de fuite ou de niveau critique
ipcMain.on('desktop:notify', (_event, { title, body, isCritical }) => {
  if (Notification.isSupported()) {
    const notif = new Notification({
      title: title || 'SMART GAS Notification',
      body: body || '',
      icon: getIconPath(),
      urgency: isCritical ? 'critical' : 'normal',
      timeoutType: isCritical ? 'never' : 'default'
    });
    notif.show();
  }
});

app.whenReady().then(() => {
  startEmbeddedServer((port) => {
    createWindow(port);
    createTray();
  });

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow(serverPort);
    }
  });
});

app.on('before-quit', () => {
  isQuitting = true;
  if (server) {
    server.close();
  }
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
