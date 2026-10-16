const { app, BrowserWindow, Menu, Tray, ipcMain, Notification, shell, dialog } = require('electron');
const path = require('path');
const fs = require('fs');

let mainWindow = null;
let tray = null;
let isQuitting = false;

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

function createWindow() {
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
      webSecurity: false // Permet de communiquer directement avec les IP locales de l'ESP32 sans blocage CORS
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
      label: 'ESP32 & Réseau',
      submenu: [
        {
          label: 'Tester le Simulateur Local (localhost:8080)',
          click: () => {
            mainWindow.webContents.executeJavaScript(`
              localStorage.setItem('smartgas_api_host', 'localhost:8080');
              window.location.reload();
            `);
          }
        },
        {
          label: 'Détecter Prototype sur Réseau Local...',
          click: async () => {
            const { response, inputValue } = await dialog.showMessageBox(mainWindow, {
              type: 'question',
              buttons: ['Annuler', 'Valider'],
              title: 'Cible ESP32',
              message: 'Entrez l\'adresse IP de votre prototype ESP32 (ex: 192.168.1.192 ou smartgas.local) :'
            });
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

  // Chargement de l'interface
  const isDev = process.env.NODE_ENV === 'development' || process.env.SMARTGAS_DEV === '1';
  if (isDev) {
    mainWindow.loadURL('http://localhost:3000');
  } else {
    const indexPath = path.join(__dirname, '..', 'web', 'dist', 'index.html');
    if (fs.existsSync(indexPath)) {
      mainWindow.loadFile(indexPath);
    } else {
      mainWindow.loadURL('http://localhost:3000');
    }
  }

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
  createWindow();
  createTray();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('before-quit', () => {
  isQuitting = true;
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
