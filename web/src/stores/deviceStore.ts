import { create } from 'zustand';
import { TelemetryData, HistoryPoint, PredictionResult, ConnectionStatus, DemoScenario } from '../types/telemetry';
import { ApiService } from '../api/client';
import { PredictionEngine } from '../utils/prediction';
import { soundSynthesizer } from '../utils/audio';

interface DeviceStoreState {
  telemetry: TelemetryData;
  history: HistoryPoint[];
  prediction: PredictionResult | null;
  status: ConnectionStatus;
  isDemo: boolean;
  demoScenario: DemoScenario;
  isWallMode: boolean;
  
  // Actions
  setTelemetry: (data: TelemetryData) => void;
  setDemoMode: (enabled: boolean) => void;
  setDemoScenario: (scenario: DemoScenario) => void;
  setWallMode: (enabled: boolean) => void;
  toggleValve: () => Promise<void>;
  muteAlarm: () => Promise<void>;
  tare: () => Promise<boolean>;
  calibrate: (weightKg: number) => Promise<boolean>;
  loadHistory: () => Promise<void>;
  initLiveFeed: () => void;
}

const INITIAL_TELEMETRY: TelemetryData = {
  device_id: 'ESP32-SMARTGAS-8A4F',
  weight_kg: 8.42,
  gross_weight_kg: 21.42,
  level_percent: 67.36,
  gas_ppm: 145,
  leak: false,
  temperature_c: 21.8,
  humidity_percent: 48.5,
  valve_state: 'OPEN',
  buzzer_muted: false,
  sensor_fault: false,
  rssi: -62,
  uptime_s: 86420,
  firmware: '1.0.0',
  timestamp: Math.floor(Date.now() / 1000)
};

export const useDeviceStore = create<DeviceStoreState>((set, get) => {
  let ws: WebSocket | null = null;
  let demoInterval: ReturnType<typeof setInterval> | null = null;

  return {
    telemetry: INITIAL_TELEMETRY,
    history: [],
    prediction: null,
    status: 'OFFLINE',
    isDemo: false,
    demoScenario: 'nominal',
    isWallMode: false,

    setTelemetry: (data: TelemetryData) => {
      const history = get().history;
      const prediction = PredictionEngine.compute(data.weight_kg, 12.5, history);
      
      if (data.leak) {
        soundSynthesizer.playCriticalAlarm();
      } else {
        soundSynthesizer.stop();
      }

      set({ telemetry: data, prediction });
    },

    setWallMode: (enabled) => set({ isWallMode: enabled }),

    setDemoMode: (enabled: boolean) => {
      if (demoInterval) clearInterval(demoInterval);
      if (ws) ws.close();

      if (enabled) {
        set({ isDemo: true, status: 'DEMO' });
        // Lancement boucle de simulation
        demoInterval = setInterval(() => {
          const scenario = get().demoScenario;
          const current = get().telemetry;
          let mock: TelemetryData;

          if (scenario === 'leak') {
            mock = {
              ...current,
              gas_ppm: 820,
              leak: true,
              valve_state: 'CLOSED',
              weight_kg: 8.12,
              level_percent: 64.9,
              timestamp: Math.floor(Date.now() / 1000)
            };
          } else if (scenario === 'low_level') {
            mock = {
              ...current,
              gas_ppm: 110,
              leak: false,
              weight_kg: 1.45,
              level_percent: 11.6,
              timestamp: Math.floor(Date.now() / 1000)
            };
          } else {
            mock = {
              ...current,
              gas_ppm: 135 + Math.floor(Math.random() * 20),
              leak: false,
              weight_kg: Math.max(0.5, current.weight_kg - 0.0002),
              level_percent: ((current.weight_kg - 0.0002) / 12.5) * 100,
              timestamp: Math.floor(Date.now() / 1000)
            };
          }
          get().setTelemetry(mock);
        }, 1000);
      } else {
        set({ isDemo: false });
        get().initLiveFeed();
      }
    },

    setDemoScenario: (scenario: DemoScenario) => {
      set({ demoScenario: scenario });
    },

    toggleValve: async () => {
      const current = get().telemetry.valve_state;
      const next = current === 'OPEN' ? 'CLOSE' : 'OPEN';

      if (get().isDemo) {
        set(state => ({
          telemetry: { ...state.telemetry, valve_state: next === 'OPEN' ? 'OPEN' : 'CLOSED' }
        }));
        return;
      }

      try {
        const res = await ApiService.controlValve(next);
        set(state => ({
          telemetry: { ...state.telemetry, valve_state: res as 'OPEN' | 'CLOSED' }
        }));
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Erreur';
        alert(`Erreur vanne : ${msg}`);
      }
    },

    muteAlarm: async () => {
      if (get().isDemo) return;
      await ApiService.muteAlarm(120);
    },

    tare: async () => {
      if (get().isDemo) return true;
      return ApiService.tare();
    },

    calibrate: async (weightKg: number) => {
      if (get().isDemo) return true;
      return ApiService.calibrate(weightKg);
    },

    loadHistory: async () => {
      try {
        const res = await ApiService.fetchHistory('day', 'hour');
        set({ history: res.points });
      } catch (e) {
        // Mock points par défaut
        const now = Math.floor(Date.now() / 1000);
        const pts: HistoryPoint[] = [];
        for (let i = 12; i >= 0; i--) {
          pts.push({
            timestamp: now - (i * 3600),
            weight_kg: 8.54 - (0.02 * (12 - i)),
            consumption_kg: 0.02
          });
        }
        set({ history: pts });
      }
    },

    initLiveFeed: () => {
      if (get().isDemo) return;

      const customHost = localStorage.getItem('sg_device_host');
      let host = customHost;
      if (!host) {
        if (typeof window !== 'undefined' && (window.location.protocol === 'file:' || !window.location.host)) {
          host = '127.0.0.1:8080';
        } else {
          host = window.location.host || '127.0.0.1:8080';
        }
      }
      host = host.replace(/^https?:\/\//, '');
      const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = `${wsProtocol}//${host}/ws`;

      try {
        ws = new WebSocket(wsUrl);

        ws.onopen = () => {
          set({ status: 'LOCAL_WS' });
        };

        ws.onmessage = (evt) => {
          try {
            const parsed = JSON.parse(evt.data);
            if (parsed.type === 'telemetry') {
              get().setTelemetry(parsed.data);
            }
          } catch (e) {
            // Ignore format error
          }
        };

        ws.onclose = () => {
          set({ status: 'OFFLINE' });
          setTimeout(() => {
            if (!get().isDemo) get().initLiveFeed();
          }, 3000);
        };

        ws.onerror = () => {
          set({ status: 'OFFLINE' });
          ws?.close();
        };
      } catch (e) {
        set({ status: 'OFFLINE' });
      }

      get().loadHistory();
    }
  };
});
