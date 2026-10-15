import React from 'react';
import { Sparkles, Calendar, AlertCircle } from 'lucide-react';
import { PredictionResult } from '../../types/telemetry';

interface PredictionCardProps {
  prediction: PredictionResult | null;
}

export const PredictionCard: React.FC<PredictionCardProps> = ({ prediction }) => {
  if (!prediction) {
    return (
      <div className="glass-panel rounded-2xl p-4 w-full">
        <div className="animate-pulse flex space-x-4">
          <div className="flex-1 space-y-3 py-1">
            <div className="h-4 bg-blue-surface rounded w-3/4"></div>
            <div className="h-8 bg-blue-surface rounded"></div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={`glass-panel rounded-2xl p-4.5 w-full transition-all ${prediction.slowLeakDetected ? 'border-alert-red border-2 shadow-alert-glow' : 'border-gold/30'}`}>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Sparkles className="w-4.5 h-4.5 text-gold" />
          <h3 className="text-sm font-bold text-gold tracking-wide">
            Estimation Prédictive d'Autonomie (IA)
          </h3>
        </div>
        <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-blue-surface/80 border border-gold/20 text-xs text-yellow-custom font-semibold">
          <Calendar className="w-3.5 h-3.5" />
          <span>Fin : {prediction.estimatedEmptyDate}</span>
        </div>
      </div>

      <div className="mt-3 flex items-baseline justify-between">
        <div>
          <span className="text-3xl font-extrabold text-text-primary tracking-tight">
            {prediction.displayStr}
          </span>
          <span className="text-xs text-text-secondary ml-2">
            (± {prediction.confidenceHours} h)
          </span>
        </div>
        <span className="text-xs font-semibold text-text-secondary bg-blue-deep/60 px-2 py-1 rounded-md">
          ~{(prediction.averageDailyConsumptionKg * 1000).toFixed(0)} g/j
        </span>
      </div>

      {prediction.slowLeakDetected && (
        <div className="mt-3 p-2.5 rounded-xl bg-alert-red/20 border border-alert-red flex items-start gap-2 text-xs text-text-primary">
          <AlertCircle className="w-4 h-4 text-alert-red shrink-0 mt-0.5" />
          <span className="font-medium">
            Attention : Décroissance de masse nocturne anormale observée. Suspicion de fuite lente !
          </span>
        </div>
      )}

      <p className="mt-2.5 text-xs text-text-secondary leading-relaxed">
        {prediction.recommendation}
      </p>
    </div>
  );
};
