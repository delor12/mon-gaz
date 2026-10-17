import { TelemetryData, HistoryResponse, DeviceConfig } from '../types/telemetry';

export class ApiService {
  private static getBaseUrl(): string {
    const customHost = localStorage.getItem('sg_device_host');
    if (customHost) {
      const host = customHost.startsWith('http') ? customHost : `http://${customHost}`;
      return `${host}/api/v1`;
    }
    if (typeof window !== 'undefined' && (window.location.protocol === 'file:' || !window.location.host)) {
      return 'http://127.0.0.1:8080/api/v1';
    }
    return '/api/v1';
  }

  private static getHeaders(): HeadersInit {
    const token = localStorage.getItem('sg_token') || 'sg_sec_default_dev_token';
    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    };
  }

  static async fetchTelemetry(): Promise<TelemetryData> {
    const res = await fetch(`${this.getBaseUrl()}/data`);
    if (!res.ok) throw new Error('Erreur récupération télémétrie');
    return res.json();
  }

  static async fetchHistory(range = 'day', resolution = 'hour'): Promise<HistoryResponse> {
    const res = await fetch(`${this.getBaseUrl()}/history?range=${range}&resolution=${resolution}`);
    if (!res.ok) throw new Error('Erreur récupération historique');
    return res.json();
  }

  static async tare(): Promise<boolean> {
    const res = await fetch(`${this.getBaseUrl()}/tare`, {
      method: 'POST',
      headers: this.getHeaders()
    });
    return res.ok;
  }

  static async calibrate(knownWeightKg: number): Promise<boolean> {
    const res = await fetch(`${this.getBaseUrl()}/calibrate`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ known_weight_kg: knownWeightKg })
    });
    return res.ok;
  }

  static async getConfig(): Promise<DeviceConfig> {
    const res = await fetch(`${this.getBaseUrl()}/config`);
    if (!res.ok) throw new Error('Erreur configuration');
    return res.json();
  }

  static async updateConfig(cfg: Partial<DeviceConfig>): Promise<boolean> {
    const res = await fetch(`${this.getBaseUrl()}/config`, {
      method: 'PUT',
      headers: this.getHeaders(),
      body: JSON.stringify(cfg)
    });
    return res.ok;
  }

  static async muteAlarm(durationSeconds = 120): Promise<boolean> {
    const res = await fetch(`${this.getBaseUrl()}/alarm/mute`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ duration_seconds: durationSeconds })
    });
    return res.ok;
  }

  static async controlValve(action: 'OPEN' | 'CLOSE'): Promise<string> {
    const res = await fetch(`${this.getBaseUrl()}/valve/control`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ action })
    });
    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.message || 'Action refusée');
    }
    const data = await res.json();
    return data.valve_state;
  }

  static async pair(pinCode: string): Promise<string> {
    const res = await fetch(`${this.getBaseUrl()}/auth/pair`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ pin_code: pinCode, client_name: 'SmartGas Web Dashboard' })
    });
    if (!res.ok) throw new Error('Code PIN invalide ou expiré');
    const data = await res.json();
    localStorage.setItem('sg_token', data.token);
    return data.token;
  }
}
