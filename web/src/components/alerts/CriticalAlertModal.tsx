import { AlertTriangle, VolumeX, ShieldAlert } from 'lucide-react';
import { useDeviceStore } from '../../stores/deviceStore';

export const CriticalAlertModal: React.FC = () => {
  const { telemetry, muteAlarm, toggleValve } = useDeviceStore();

  if (!telemetry.leak) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-md animate-fade-in">
      <div className="relative w-full max-w-lg bg-alert-red/20 border-2 border-alert-red rounded-3xl p-6 shadow-alert-glow text-text-primary animate-pulse-alarm">
        {/* En-tête d'Urgence */}
        <div className="flex flex-col items-center text-center">
          <div className="w-16 h-16 rounded-full bg-alert-red flex items-center justify-center mb-3 shadow-lg">
            <AlertTriangle className="w-10 h-10 text-white animate-bounce" />
          </div>
          <h2 className="text-2xl font-black text-white tracking-wider">
            ! DANGER IMMÉDIAT !
          </h2>
          <p className="text-base font-bold text-yellow-custom mt-1">
            FUITE DE GAZ GPL DÉTECTÉE ({telemetry.gas_ppm} PPM)
          </p>
          <span className="text-xs text-text-secondary mt-1">
            L'électrovanne a été automatiquement coupée pour votre sécurité.
          </span>
        </div>

        {/* Consignes de Sécurité Prioritaires */}
        <div className="mt-5 bg-black/50 border border-white/20 rounded-2xl p-4 text-xs space-y-2.5">
          <h4 className="font-bold text-white uppercase tracking-wider text-[11px]">
            Consignes de Sécurité Vitales :
          </h4>
          <div className="flex items-start gap-2.5">
            <span className="w-5 h-5 rounded-full bg-yellow-custom text-blue-deep font-bold flex items-center justify-center shrink-0">1</span>
            <span>Ne touchez à <strong>AUCUN interrupteur électrique</strong>, flamme, ou appareil électronique.</span>
          </div>
          <div className="flex items-start gap-2.5">
            <span className="w-5 h-5 rounded-full bg-yellow-custom text-blue-deep font-bold flex items-center justify-center shrink-0">2</span>
            <span><strong>Fermez immédiatement le robinet</strong> supérieur de la bouteille de gaz.</span>
          </div>
          <div className="flex items-start gap-2.5">
            <span className="w-5 h-5 rounded-full bg-yellow-custom text-blue-deep font-bold flex items-center justify-center shrink-0">3</span>
            <span>Ouvrez grandement les portes et fenêtres pour <strong>ventiler l'espace</strong>.</span>
          </div>
          <div className="flex items-start gap-2.5">
            <span className="w-5 h-5 rounded-full bg-yellow-custom text-blue-deep font-bold flex items-center justify-center shrink-0">4</span>
            <span>Évacuez le domicile si la concentration persiste et contactez les pompiers (18/112).</span>
          </div>
        </div>

        {/* Boutons d'Action Rapide */}
        <div className="mt-6 flex flex-col sm:flex-row gap-3">
          <button
            onClick={() => muteAlarm()}
            className="flex-1 py-3 px-4 rounded-xl bg-yellow-custom hover:bg-yellow-hover text-blue-deep font-bold text-sm flex items-center justify-center gap-2 transition-transform active:scale-95 shadow-md"
          >
            <VolumeX className="w-4 h-4" />
            <span>Sourdine Buzzer (2 min)</span>
          </button>

          <button
            onClick={() => toggleValve()}
            className="flex-1 py-3 px-4 rounded-xl bg-alert-red hover:bg-alert-red/90 text-white font-bold text-sm flex items-center justify-center gap-2 transition-transform active:scale-95 border border-white/20 shadow-md"
          >
            <ShieldAlert className="w-4 h-4" />
            <span>{telemetry.valve_state === 'OPEN' ? 'Couper Vanne Gaz' : 'Vanne Coupée'}</span>
          </button>
        </div>
      </div>
    </div>
  );
};
