import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'masked-icon.svg'],
      manifest: {
        name: 'SMART GAS - Moniteur GPL Intelligent',
        short_name: 'SmartGas',
        description: 'Surveillance de niveau et détection de fuite de bouteille de gaz GPL',
        theme_color: '#061A45',
        background_color: '#061A45',
        display: 'standalone',
        orientation: 'portrait',
        icons: [
          {
            src: 'pwa-192x192.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: 'pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'any maskable'
          }
        ]
      }
    })
  ],
  server: {
    port: 3000,
    host: true,
    allowedHosts: true,
    proxy: {
      '/api': {
        target: process.env.VITE_ESP32_HOST 
          ? (process.env.VITE_ESP32_HOST.startsWith('http') ? process.env.VITE_ESP32_HOST : `http://${process.env.VITE_ESP32_HOST}`) 
          : 'http://localhost:8080',
        changeOrigin: true
      },
      '/ws': {
        target: process.env.VITE_ESP32_HOST 
          ? (process.env.VITE_ESP32_HOST.startsWith('ws') ? process.env.VITE_ESP32_HOST : `ws://${process.env.VITE_ESP32_HOST.replace(/^https?:\/\//, '')}`) 
          : 'ws://localhost:8080',
        ws: true
      }
    }
  }
});
