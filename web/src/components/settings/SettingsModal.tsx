import React, { useState } from 'react';
import { X, Wrench, Shield, Wifi, PlayCircle } from 'lucide-react';
import { useDeviceStore } from '../../stores/deviceStore';
import { DemoScenario } from '../../types/telemetry';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({ isOpen, onClose }) => {
  const { isDemo, demoScenario, setDemoMode, setDemoScenario, tare, calibrate } = useDeviceStore();
  const [host, setHost] = useState(localStorage.getItem('sg_device_host') || 'smartgas.local');
  const [calWeight, setCalWeight] = useState('5.0');
  const [savedMsg, setSavedMsg] = useState('');

  if (!isOpen) return null;

  const handleSaveHost = () => {
    localStorage.setItem('sg_device_host', host.trim());
    setSavedMsg('Hôte enregistré. Reconnexion...');
    setTimeout(() => {
      setSavedMsg('');
      window.location.reload();
    }, 1000);
  };

  const handleTare = async () => {
    const ok = await tare();
    alert(ok ? 'Tare effectuée avec succès !' : 'Échec de la tare');
  };

  const handleCalibrate = async () => {
    const w = parseFloat(calWeight);
    if (isNaN(w) || w <= 0) return alert('Poids invalide');
    const ok = await calibrate(w);
    alert(ok ? `Étalonnage à ${w} kg réussi !` : 'Échec étalonnage');
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fade-in">
      <div className="relative w-full max-w-lg glass-panel rounded-3xl p-6 border-gold/40 shadow-2xl max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-gold/20 pb-3">
          <h2 className="text-lg font-bold text-gold flex items-center gap-2">
            <Wrench className="w-5 h-5 text-gold" />
            Paramètres du Dispositif
          </h2>
          <button
            onClick={onClose}
            className="p-1 rounded-lg text-text-secondary hover:text-white hover:bg-white/10"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* 1. Mode Démo */}
        <div className="mt-5 p-4 rounded-2xl bg-yellow-custom/10 border border-yellow-custom/30">
          <div className="flex items-center justify-between">
            <div>
              <span className="text-sm font-bold text-yellow-custom flex items-center gap-2">
                <PlayCircle className="w-4 h-4" /> Mode Démo (Simulateur)
              </span>
              <p className="text-xs text-text-secondary mt-0.5">
                Tester sans matériel réel connecté
              </p>
            </div>
            <input
              type="checkbox"
              checked={isDemo}
              onChange={(e) => setDemoMode(e.target.checked)}
              className="w-5 h-5 accent-yellow-custom cursor-pointer"
            />
          </div>

          {isDemo && (
            <div className="mt-3 pt-3 border-t border-yellow-custom/20">
              <label className="text-xs font-semibold text-text-primary block mb-1.5">
                Choisir un scénario simulé :
              </label>
              <div className="flex gap-2">
                {(['nominal', 'leak', 'low_level'] as DemoScenario[]).map((sc) => (
                  <button
                    key={sc}
                    onClick={() => setDemoScenario(sc)}
                    className={`flex-1 py-1.5 text-xs font-bold rounded-lg border transition-all ${
                      demoScenario === sc
                        ? 'bg-yellow-custom text-blue-deep border-yellow-custom'
                        : 'border-yellow-custom/30 text-yellow-custom hover:bg-yellow-custom/20'
                    }`}
                  >
                    {sc === 'nominal' ? 'Nominal' : sc === 'leak' ? '🚨 Fuite' : 'Niveau Bas'}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* 2. Hôte Réseau */}
        <div className="mt-5 space-y-2">
          <label className="text-xs font-bold text-gold flex items-center gap-1.5">
            <Wifi className="w-4 h-4" /> Adresse Réseau de l'ESP32
          </label>
          <div className="flex gap-2">
            <input
              type="text"
              value={host}
              onChange={(e) => setHost(e.target.value)}
              placeholder="smartgas.local ou 192.168.1.50"
              className="flex-1 bg-blue-deep/70 border border-gold/30 rounded-xl px-3 py-2 text-sm text-text-primary focus:outline-none focus:border-gold"
            />
            <button
              onClick={handleSaveHost}
              className="px-4 py-2 bg-blue-light hover:bg-blue-light/80 text-white rounded-xl text-xs font-bold transition-colors"
            >
              Enregistrer
            </button>
          </div>
          {savedMsg && <p className="text-xs text-green-ok">{savedMsg}</p>}
        </div>

        {/* 3. Étalonnage et Tare */}
        <div className="mt-5 space-y-3 pt-4 border-t border-gold/20">
          <label className="text-xs font-bold text-gold flex items-center gap-1.5">
            <Shield className="w-4 h-4" /> Étalonnage Cellule HX711
          </label>
          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={handleTare}
              className="py-2.5 px-3 rounded-xl border border-gold/40 hover:bg-gold/10 text-xs font-bold text-text-primary transition-colors"
            >
              Tare (Plateau à 0 kg)
            </button>

            <div className="flex gap-1.5">
              <input
                type="number"
                step="0.5"
                value={calWeight}
                onChange={(e) => setCalWeight(e.target.value)}
                className="w-16 bg-blue-deep/70 border border-gold/30 rounded-xl px-2 text-center text-xs text-text-primary"
              />
              <button
                onClick={handleCalibrate}
                className="flex-1 py-2.5 px-2 bg-gold hover:bg-gold-light text-blue-deep rounded-xl text-xs font-bold transition-colors"
              >
                Étalonner
              </button>
            </div>
          </div>
        </div>

        {/* Pied */}
        <div className="mt-6 pt-3 border-t border-gold/20 flex justify-end">
          <button
            onClick={onClose}
            className="px-5 py-2 rounded-xl bg-blue-surface hover:bg-blue-surface/80 text-text-primary text-xs font-bold transition-colors"
          >
            Fermer
          </button>
        </div>
      </div>
    </div>
  );
};
