import React from 'react';

interface CircularGaugeProps {
  percent: number;
  weightKg: number;
  size?: number;
}

export const CircularGauge: React.FC<CircularGaugeProps> = ({
  percent,
  weightKg,
  size = 240
}) => {
  const clamped = Math.max(0, Math.min(100, percent));
  const strokeWidth = 14;
  const radius = (size - strokeWidth * 2) / 2;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (clamped / 100) * circumference;

  let strokeColor = '#D4AF37'; // Or par défaut
  if (clamped <= 5) {
    strokeColor = '#E5383B'; // Alerte critique rouge
  } else if (clamped <= 15) {
    strokeColor = '#FFD60A'; // Avertissement jaune
  }

  return (
    <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
      <svg className="w-full h-full -rotate-90 transform" viewBox={`0 0 ${size} ${size}`}>
        <defs>
          <linearGradient id="goldGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#F5D76E" />
            <stop offset="100%" stopColor="#D4AF37" />
          </linearGradient>
        </defs>

        {/* Piste d'arrière-plan */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="rgba(255, 255, 255, 0.08)"
          strokeWidth={strokeWidth}
        />

        {/* Arc actif de la jauge */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={clamped > 15 ? 'url(#goldGradient)' : strokeColor}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={strokeDashoffset}
          className="transition-all duration-700 ease-out"
        />
      </svg>

      {/* Valeurs centrées */}
      <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
        <span
          className="text-4xl font-extrabold tracking-tight transition-colors duration-300"
          style={{ color: strokeColor }}
        >
          {clamped.toFixed(1)} %
        </span>
        <span className="text-xl font-bold text-text-primary mt-1">
          {weightKg.toFixed(2)} kg
        </span>
        <span className="text-xs font-medium text-text-secondary">
          Gaz restant
        </span>
      </div>
    </div>
  );
};
