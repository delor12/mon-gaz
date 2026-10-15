import { PredictionEngine } from './prediction';
import { HistoryPoint } from '../types/telemetry';

describe('PredictionEngine TypeScript Unit Tests', () => {
  it('should handle empty bottle gracefully', () => {
    const res = PredictionEngine.compute(0.01, 12.5, []);
    expect(res.daysRemaining).toBe(0);
    expect(res.hoursRemaining).toBe(0);
    expect(res.displayStr).toContain('Vide');
    expect(res.slowLeakDetected).toBe(false);
  });

  it('should provide heuristic estimation when history is scarce', () => {
    const res = PredictionEngine.compute(8.42, 12.5, [
      { timestamp: 1700000000, weight_kg: 8.5, consumption_kg: 0.05 }
    ]);
    expect(res.daysRemaining).toBeGreaterThan(20);
    expect(res.averageDailyConsumptionKg).toBeCloseTo(0.35, 2);
  });

  it('should accurately compute linear consumption slope', () => {
    const now = Math.floor(Date.now() / 1000);
    const history: HistoryPoint[] = [];
    for (let i = 10; i >= 1; i--) {
      history.push({
        timestamp: now - (i * 86400),
        weight_kg: 12.0 - (0.5 * (10 - i)),
        consumption_kg: 0.5
      });
    }

    const res = PredictionEngine.compute(7.0, 12.5, history);
    expect(res.daysRemaining).toBeGreaterThanOrEqual(12);
    expect(res.daysRemaining).toBeLessThanOrEqual(16);
    expect(res.averageDailyConsumptionKg).toBeCloseTo(0.5, 1);
  });
});
