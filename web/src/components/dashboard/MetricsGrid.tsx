import React from 'react';
import { Scale, Flame, Thermometer, ShieldCheck, ShieldAlert } from 'lucide-react';
import { TelemetryData } from '../../types/telemetry';

interface MetricsGridProps {
  telemetry: TelemetryData;
}

export const MetricsGrid: React.FC<MetricsGridProps> = ({ telemetry }) => {
  const isValveOpen = telemetry.valve_state === 'OPEN';

  return (
    <div className="grid grid-cols-2 gap-3 w-full">
      {/* 1. Poids Brut */}
      <div className="glass-panel rounded-xl p-3.5 flex flex-col items-center text-center">
        <Scale className="w-5 h-5 text-gold mb-1.5" />
        <span className="text-xs text-text-secondary">Poids Brut Total</span>
        <span className="text-lg font-bold text-text-primary mt-0.5">
          {telemetry.gross_weight_kg.toFixed(2)} kg
        </span>
      </div>

      {/* 2. Gaz GPL */}
      <div className="glass-panel rounded-xl p-3.5 flex flex-col items-center text-center">
        <Flame className={`w-5 h-5 mb-1.5 ${telemetry.leak ? 'text-alert-red animate-bounce' : 'text-gold'}`} />
        <span className="text-xs text-text-secondary">Concentration GPL</span>
        <span className={`text-lg font-bold mt-0.5 ${telemetry.leak ? 'text-alert-red' : 'text-text-primary'}`}>
          {telemetry.gas_ppm} ppm
        </span>
      </div>

      {/* 3. Température */}
      <div className="glass-panel rounded-xl p-3.5 flex flex-col items-center text-center">
        <Thermometer className="w-5 h-5 text-gold mb-1.5" />
        <span className="text-xs text-text-secondary">Température</span>
        <span className="text-lg font-bold text-text-primary mt-0.5">
          {telemetry.temperature_c.toFixed(1)} °C
        </span>
      </div>

      {/* 4. Électrovanne */}
      <div className="glass-panel rounded-xl p-3.5 flex flex-col items-center text-center">
        {isValveOpen ? (
          <ShieldCheck className="w-5 h-5 text-green-ok mb-1.5" />
        ) : (
          <ShieldAlert className="w-5 h-5 text-alert-red mb-1.5" />
        )}
        <span className="text-xs text-text-secondary">Électrovanne</span>
        <span className={`text-lg font-bold mt-0.5 ${isValveOpen ? 'text-green-ok' : 'text-alert-red'}`}>
          {isValveOpen ? 'OUVERTE' : 'FERMÉE'}
        </span>
      </div>
    </div>
  );
};
