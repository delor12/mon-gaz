export interface TelemetryData {
  device_id: string;
  weight_kg: number;
  gross_weight_kg: number;
  level_percent: number;
  gas_ppm: number;
  leak: boolean;
  temperature_c: number;
  humidity_percent?: number;
  valve_state: 'OPEN' | 'CLOSED' | 'DISABLED';
  buzzer_muted?: boolean;
  sensor_fault?: boolean;
  rssi?: number;
  uptime_s?: number;
  firmware?: string;
  timestamp: number;
}

export interface HistoryPoint {
  timestamp: number;
  weight_kg: number;
  consumption_kg: number;
}

export interface HistoryResponse {
  range: string;
  resolution: string;
  count: number;
  points: HistoryPoint[];
}

export interface DeviceConfig {
  bottle_type: string;
  bottle_name: string;
  capacity_kg: number;
  tare_weight_kg: number;
  leak_threshold_ppm: number;
  low_level_threshold_percent: number;
  critical_level_threshold_percent: number;
  buzzer_enabled: boolean;
  valve_enabled: boolean;
  valve_auto_cutoff: boolean;
}

export interface PredictionResult {
  daysRemaining: number;
  hoursRemaining: number;
  displayStr: string;
  estimatedEmptyDate: string;
  averageDailyConsumptionKg: number;
  confidenceHours: number;
  slowLeakDetected: boolean;
  recommendation: string;
}

export type ConnectionStatus = 'LOCAL_WS' | 'CLOUD_MQTT' | 'DEMO' | 'OFFLINE';
export type DemoScenario = 'nominal' | 'leak' | 'low_level';
