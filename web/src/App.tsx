import React, { useEffect, useState } from 'react';
import { Settings, Maximize2, Power } from 'lucide-react';
import { useDeviceStore } from './stores/deviceStore';
import { CircularGauge } from './components/dashboard/CircularGauge';
import { MetricsGrid } from './components/dashboard/MetricsGrid';
import { PredictionCard } from './components/dashboard/PredictionCard';
import { ConsumptionChart } from './components/charts/ConsumptionChart';
import { CriticalAlertModal } from './components/alerts/CriticalAlertModal';
import { WallDisplayView } from './components/wall_display/WallDisplayView';
import { SettingsModal } from './components/settings/SettingsModal';

export const App: React.FC = () => {
  const {
    telemetry,
    history,
    prediction,
    status,
    isWallMode,
    setWallMode,
    toggleValve,
    initLiveFeed
  } = useDeviceStore();

  const [isSettingsOpen, setIsSettingsOpen] = useState(false);

  useEffect(() => {
    initLiveFeed();
  }, [initLiveFeed]);

  if (isWallMode) {
    return <WallDisplayView />;
  }

  const isValveOpen = telemetry.valve_state === 'OPEN';

  return (
    <div className="min-h-screen bg-blue-deep text-text-primary flex flex-col font-sans">
      <CriticalAlertModal />
      <SettingsModal isOpen={isSettingsOpen} onClose={() => setIsSettingsOpen(false)} />

      {/* En-tête */}
      <header className="sticky top-0 z-30 bg-blue-deep/80 backdrop-blur-md border-b border-gold/20 px-4 py-3.5 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <span className="text-2xl">🔥</span>
          <div>
            <h1 className="text-lg font-black text-gold tracking-wider">SMART GAS</h1>
            <p className="text-[10px] text-text-secondary tracking-normal">Moniteur GPL Intelligent</p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {/* Statut Réseau */}
          <div className="flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold border transition-colors bg-blue-surface/60 border-gold/30">
            <span
              className={`w-2 h-2 rounded-full ${
                status === 'LOCAL_WS'
                  ? 'bg-green-ok'
                  : status === 'DEMO'
                  ? 'bg-yellow-custom'
                  : 'bg-alert-red'
              }`}
            />
            <span className="text-[11px] text-text-secondary">
              {status === 'LOCAL_WS' ? 'LAN (Direct)' : status === 'DEMO' ? 'Mode Démo' : 'Hors Ligne'}
            </span>
          </div>

          {/* Mode Mural */}
          <button
            onClick={() => setWallMode(true)}
            className="p-2 rounded-xl bg-blue-surface hover:bg-gold/20 text-gold transition-colors border border-gold/20"
            title="Activer l'affichage mural"
          >
            <Maximize2 className="w-4 h-4" />
          </button>

          {/* Paramètres */}
          <button
            onClick={() => setIsSettingsOpen(true)}
            className="p-2 rounded-xl bg-blue-surface hover:bg-gold/20 text-gold transition-colors border border-gold/20"
            title="Paramètres"
          >
            <Settings className="w-4 h-4" />
          </button>
        </div>
      </header>

      {/* Contenu Principal Responsive */}
      <main className="flex-1 max-w-xl w-full mx-auto p-4 flex flex-col gap-4">
        {/* Jauge Principale Circulaire */}
        <section className="glass-panel rounded-3xl p-6 flex flex-col items-center justify-center">
          <CircularGauge
            percent={telemetry.level_percent}
            weightKg={telemetry.weight_kg}
            size={220}
          />
          <span className="text-xs text-text-secondary mt-3">
            Bouteille 12.5 kg • Cuisine Principale
          </span>
        </section>

        {/* Grille de Métriques */}
        <MetricsGrid telemetry={telemetry} />

        {/* Carte de Prédiction IA */}
        <PredictionCard prediction={prediction} />

        {/* Contrôle de l'Électrovanne */}
        <div className="flex gap-3">
          <button
            onClick={() => toggleValve()}
            className={`flex-1 py-3.5 px-4 rounded-2xl font-bold text-sm flex items-center justify-center gap-2 transition-all shadow-md active:scale-95 ${
              isValveOpen
                ? 'bg-blue-light hover:bg-blue-light/90 text-white'
                : 'bg-green-ok hover:bg-green-ok/90 text-blue-deep'
            }`}
          >
            <Power className="w-4 h-4" />
            <span>{isValveOpen ? 'Fermer Électrovanne' : 'Ouvrir Électrovanne'}</span>
          </button>
        </div>

        {/* Graphique de Consommation Recharts */}
        <ConsumptionChart points={history} />
      </main>

      {/* Pied de page */}
      <footer className="text-center py-4 text-[11px] text-text-secondary border-t border-gold/10">
        SmartGas v1.0 • Sécurité Prioritaire Autonome • Local-First Architecture
      </footer>
    </div>
  );
};

export default App;
