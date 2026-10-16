const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('smartGasDesktop', {
  isDesktop: true,
  platform: process.platform,
  version: '1.0.0',
  sendNotification: (title, body, isCritical = false) => {
    ipcRenderer.send('desktop:notify', { title, body, isCritical });
  },
  minimizeToTray: () => {
    ipcRenderer.send('desktop:minimize-to-tray');
  },
  onEsp32Status: (callback) => {
    ipcRenderer.on('desktop:esp-status', (_event, data) => callback(data));
  }
});
