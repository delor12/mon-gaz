import 'package:flutter_test/flutter_test.dart';
import 'package:smartgas/features/prediction/prediction_engine.dart';
import 'package:smartgas/shared/models/telemetry.dart';

void main() {
  group('PredictionEngine Dart Unit Tests', () {
    test('Empty bottle returns 0 days remaining', () {
      final res = PredictionEngine.compute(
        currentWeightKg: 0.02,
        capacityKg: 12.5,
        history: [],
      );

      expect(res.daysRemaining, 0);
      expect(res.hoursRemaining, 0);
      expect(res.displayStr.contains('Vide'), isTrue);
      expect(res.slowLeakDetected, isFalse);
    });

    test('Initial phase heuristic estimation', () {
      final res = PredictionEngine.compute(
        currentWeightKg: 8.42,
        capacityKg: 12.5,
        history: [
          const HistoryPoint(timestamp: 1700000000, weightKg: 8.50, consumptionKg: 0.05),
        ],
      );

      expect(res.daysRemaining, greaterThan(20));
      expect(res.averageDailyConsumptionKg, closeTo(0.350, 0.01));
    });

    test('Weighted linear regression calculation', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final history = <HistoryPoint>[];
      for (int i = 10; i >= 1; i--) {
        history.add(HistoryPoint(
          timestamp: now - (i * 86400),
          weightKg: 12.0 - (0.5 * (10 - i)),
          consumptionKg: 0.5,
        ));
      }

      final res = PredictionEngine.compute(
        currentWeightKg: 7.0,
        capacityKg: 12.5,
        history: history,
      );

      expect(res.daysRemaining, inInclusiveRange(12, 16));
      expect(res.averageDailyConsumptionKg, closeTo(0.5, 0.1));
    });
  });
}
