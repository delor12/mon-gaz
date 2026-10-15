import { HistoryPoint, PredictionResult } from '../types/telemetry';

export class PredictionEngine {
  static compute(
    currentWeightKg: number,
    _capacityKg: number,
    history: HistoryPoint[]
  ): PredictionResult {
    if (currentWeightKg <= 0.05) {
      return {
        daysRemaining: 0,
        hoursRemaining: 0,
        displayStr: '0 j : 00 min (Vide)',
        estimatedEmptyDate: new Date().toLocaleDateString('fr-FR'),
        averageDailyConsumptionKg: 0,
        confidenceHours: 0,
        slowLeakDetected: false,
        recommendation: 'Bouteille vide. Veuillez la remplacer par une nouvelle bouteille pleine.',
      };
    }

    if (history.length < 5) {
      const defaultDailyConso = 0.35; // 350g par jour
      const totalDays = currentWeightKg / defaultDailyConso;
      const days = Math.floor(totalDays);
      const hours = Math.round((totalDays - days) * 24);
      const emptyDate = new Date(Date.now() + (days * 86400000) + (hours * 3600000));

      return {
        daysRemaining: days,
        hoursRemaining: hours,
        displayStr: `${days} j : ${String(hours).padStart(2, '0')} h`,
        estimatedEmptyDate: emptyDate.toLocaleDateString('fr-FR'),
        averageDailyConsumptionKg: defaultDailyConso,
        confidenceHours: 48,
        slowLeakDetected: false,
        recommendation: "Apprentissage des habitudes du foyer en cours sur 7 jours.",
      };
    }

    // Régression Linéaire Pondérée (WLR)
    const timestamps = history.map(p => p.timestamp);
    const tMax = Math.max(...timestamps);
    const tMin = Math.min(...timestamps);
    const lambda = Math.log(2.0) / (3.0 * 86400.0);

    let sumW = 0;
    let sumWT = 0;
    let sumWY = 0;
    const weights: number[] = [];

    for (const p of history) {
      const w = Math.exp(-lambda * (tMax - p.timestamp));
      weights.push(w);
      sumW += w;
      sumWT += w * (p.timestamp - tMin);
      sumWY += w * p.weight_kg;
    }

    const meanT = sumWT / sumW;
    const meanY = sumWY / sumW;

    let num = 0;
    let den = 0;
    for (let i = 0; i < history.length; i++) {
      const t = history[i].timestamp - tMin;
      const y = history[i].weight_kg;
      const w = weights[i];
      num += w * (t - meanT) * (y - meanY);
      den += w * Math.pow(t - meanT, 2);
    }

    const slope = den !== 0 ? num / den : -0.35 / 86400.0;
    const dailyConso = Math.max(0.08, -slope * 86400.0);

    const totalDays = currentWeightKg / dailyConso;
    const days = Math.floor(totalDays);
    const hours = Math.round((totalDays - days) * 24);
    const emptyDate = new Date(Date.now() + (days * 86400000) + (hours * 3600000));

    // Détection de micro-fuite nocturne
    let slowLeak = false;
    for (let i = 1; i < history.length; i++) {
      const dt = new Date(history[i].timestamp * 1000);
      const hour = dt.getUTCHours();
      if (hour >= 1 && hour <= 5) {
        const dw = history[i - 1].weight_kg - history[i].weight_kg;
        const dtHours = (history[i].timestamp - history[i - 1].timestamp) / 3600.0;
        if (dtHours > 0.5 && dw / dtHours > 0.02) {
          slowLeak = true;
          break;
        }
      }
    }

    let rec = "Consommation nominale optimale.";
    if (slowLeak) {
      rec = "⚠️ Suspicion de micro-fuite lente : perte de gaz nocturne anormale observée !";
    } else if (days <= 3) {
      rec = "⚠️ Moins de 3 jours d'autonomie. Pensez à commander votre recharge.";
    }

    return {
      daysRemaining: days,
      hoursRemaining: hours,
      displayStr: `${days} j : ${String(hours).padStart(2, '0')} h`,
      estimatedEmptyDate: emptyDate.toLocaleDateString('fr-FR'),
      averageDailyConsumptionKg: Math.round(dailyConso * 1000) / 1000,
      confidenceHours: Math.min(72, Math.max(12, Math.round(totalDays * 2.5))),
      slowLeakDetected: slowLeak,
      recommendation: rec,
    };
  }
}
