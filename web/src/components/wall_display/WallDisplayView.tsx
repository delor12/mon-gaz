import React from 'react';
import { Minimize2, Flame, Scale, Thermometer } from 'lucide-react';
import { CircularGauge } from '../dashboard/CircularGauge';
import { useDeviceStore } from '../../stores/deviceStore';

export const WallDisplayView: React.FC = () => {
  const { telemetry, prediction, setWallMode } = useDeviceStore();

  return (
    <div className="fixed inset-0 z-40 bg-blue-deep flex flex-col justify-between p-8 select-none">
      {/* Barre supérieure */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="text-3xl">🔥</span>
          <div>
            <h1 className="text-2xl font-black text-gold tracking-wider">SMART GAS</h1>
            <p className="text-xs text-text-secondary">Affichage Mural Haute Visibilité</p>
          </div>
        </div>

        <button
          onClick={() => setWallMode(false)}
          className="p-3 rounded-2xl bg-blue-surface border border-gold/30 text-gold hover:bg-gold hover:text-blue-deep transition-colors"
          title="Quitter le mode mural"
        >
          <Minimize2 className="w-6 h-6" />
        </button>
      </div>

      {/* Centre : Jauge Gigantesque */}
      <div className="flex flex-col items-center justify-center my-auto">
        <CircularGauge
          percent={telemetry.level_percent}
          weightKg={telemetry.weight_kg}
          size={360}
        />
        <div className="mt-6 text-center">
          <span className="text-2xl font-extrabold text-gold tracking-wide">
            Autonomie : {prediction?.displayStr ?? '-- j'}
          </span>
          <p className="text-sm text-text-secondary mt-1">
            Date estimée d'épuisement : {prediction?.estimatedEmptyDate ?? '--/--'}
          </p>
        </div>
      </div>

      {/* Pied : Métriques Grosses Icônes */}
      <div className="grid grid-cols-3 gap-6">
        <div className="glass-panel rounded-2xl p-4 flex items-center justify-center gap-4">
          <Scale className="w-8 h-8 text-gold" />
          <div>
            <span className="text-xs text-text-secondary block">Poids Brut</span>
            <span className="text-xl font-bold">{telemetry.gross_weight_kg.toFixed(2)} kg</span>
          </div>
        </div>

        <div className="glass-panel rounded-2xl p-4 flex items-center justify-center gap-4">
          <Flame className={`w-8 h-8 ${telemetry.leak ? 'text-alert-red animate-bounce' : 'text-gold'}`} />
          <div>
            <span className="text-xs text-text-secondary block">Gaz GPL</span>
            <span className={`text-xl font-bold ${telemetry.leak ? 'text-alert-red' : ''}`}>
              {telemetry.gas_ppm} ppm
            </span>
          </div>
        </div>

        <div className="glass-panel rounded-2xl p-4 flex items-center justify-center gap-4">
          <Thermometer className="w-8 h-8 text-gold" />
          <div>
            <span className="text-xs text-text-secondary block">Température</span>
            <span className="text-xl font-bold">{telemetry.temperature_c.toFixed(1)} °C</span>
          </div>
        </div>
      </div>
    </div>
  );
};
