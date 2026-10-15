import React, { useState } from 'react';
import {
  AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid
} from 'recharts';
import { HistoryPoint } from '../../types/telemetry';

interface ConsumptionChartProps {
  points: HistoryPoint[];
}

export const ConsumptionChart: React.FC<ConsumptionChartProps> = ({ points }) => {
  const [range, setRange] = useState<'day' | 'week' | 'month'>('day');

  // Formatage des données pour Recharts
  const chartData = points.map(p => {
    const d = new Date(p.timestamp * 1000);
    const label = range === 'day' 
      ? `${d.getHours()}h` 
      : `${d.getDate()}/${d.getMonth() + 1}`;

    return {
      time: label,
      weight: p.weight_kg,
      consumption: Math.round(p.consumption_kg * 1000)
    };
  });

  return (
    <div className="glass-panel rounded-2xl p-4 w-full">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-bold text-gold tracking-wide">
          Historique de Masse Restante (kg)
        </h3>
        <div className="flex gap-1 bg-blue-deep/60 p-1 rounded-xl border border-gold/20">
          {(['day', 'week', 'month'] as const).map(tab => (
            <button
              key={tab}
              onClick={() => setRange(tab)}
              className={`px-2.5 py-1 text-xs font-bold rounded-lg transition-all ${
                range === tab
                  ? 'bg-gold text-blue-deep shadow-sm'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              {tab === 'day' ? '24h' : tab === 'week' ? '7j' : '30j'}
            </button>
          ))}
        </div>
      </div>

      <div className="h-56 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
            <defs>
              <linearGradient id="colorWeight" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#D4AF37" stopOpacity={0.4} />
                <stop offset="95%" stopColor="#D4AF37" stopOpacity={0.0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.08)" />
            <XAxis dataKey="time" stroke="#6C82A6" fontSize={11} tickLine={false} />
            <YAxis stroke="#6C82A6" fontSize={11} domain={[0, 15]} tickLine={false} />
            <Tooltip
              contentStyle={{
                backgroundColor: '#0A2A6B',
                borderColor: '#D4AF37',
                borderRadius: '8px',
                color: '#F5F7FA',
                fontSize: '12px'
              }}
              formatter={(val: number) => [`${val.toFixed(2)} kg`, 'Masse']}
            />
            <Area
              type="monotone"
              dataKey="weight"
              stroke="#D4AF37"
              strokeWidth={3}
              fillOpacity={1}
              fill="url(#colorWeight)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
};
