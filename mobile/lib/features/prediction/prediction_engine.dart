import 'dart:math';
import 'package:intl/intl.dart';
import '../../shared/models/telemetry.dart';

class PredictionResult {
  final int daysRemaining;
  final int hoursRemaining;
  final String displayStr;
  final String estimatedEmptyDate;
  final double averageDailyConsumptionKg;
  final int confidenceHours;
  final bool slowLeakDetected;
  final String recommendation;

  const PredictionResult({
    required this.daysRemaining,
    required this.hoursRemaining,
    required this.displayStr,
    required this.estimatedEmptyDate,
    required this.averageDailyConsumptionKg,
    required this.confidenceHours,
    required this.slowLeakDetected,
    required this.recommendation,
  });
}

class PredictionEngine {
  static PredictionResult compute({
    required double currentWeightKg,
    required double capacityKg,
    required List<HistoryPoint> history,
  }) {
    if (currentWeightKg <= 0.05) {
      return PredictionResult(
        daysRemaining: 0,
        hoursRemaining: 0,
        displayStr: '0 j : 00 min (Vide)',
        estimatedEmptyDate: DateFormat('dd/MM/yyyy').format(DateTime.now()),
        averageDailyConsumptionKg: 0.0,
        confidenceHours: 0,
        slowLeakDetected: false,
        recommendation: 'Bouteille vide. Veuillez la remplacer par une nouvelle bouteille pleine.',
      );
    }

    if (history.length < 5) {
      const defaultDailyConso = 0.350; // 350g par jour
      final totalDays = currentWeightKg / defaultDailyConso;
      final days = totalDays.toInt();
      final hours = ((totalDays - days) * 24).toInt();
      final emptyDate = DateTime.now().add(Duration(days: days, hours: hours));

      return PredictionResult(
        daysRemaining: days,
        hoursRemaining: hours,
        displayStr: '$days j : ${hours.toString().padLeft(2, '0')} h',
        estimatedEmptyDate: DateFormat('dd/MM/yyyy').format(emptyDate),
        averageDailyConsumptionKg: defaultDailyConso,
        confidenceHours: 48,
        slowLeakDetected: false,
        recommendation: "Apprentissage des habitudes du foyer en cours.",
      );
    }

    // Régression Linéaire Pondérée (WLR)
    double sumW = 0.0;
    double sumWT = 0.0;
    double sumWY = 0.0;
    final tMax = history.map((e) => e.timestamp).reduce(max).toDouble();
    final tMin = history.map((e) => e.timestamp).reduce(min).toDouble();
    final lambda = log(2.0) / (3.0 * 86400.0);

    final weights = <double>[];
    for (final p in history) {
      final w = exp(-lambda * (tMax - p.timestamp));
      weights.add(w);
      sumW += w;
      sumWT += w * (p.timestamp - tMin);
      sumWY += w * p.weightKg;
    }

    final meanT = sumWT / sumW;
    final meanY = sumWY / sumW;

    double num = 0.0;
    double den = 0.0;
    for (int i = 0; i < history.length; i++) {
      final t = history[i].timestamp - tMin;
      final y = history[i].weightKg;
      final w = weights[i];
      num += w * (t - meanT) * (y - meanY);
      den += w * pow(t - meanT, 2);
    }

    final slope = (den != 0) ? (num / den) : (-0.350 / 86400.0);
    final dailyConso = max(0.080, -slope * 86400.0);

    final totalDays = currentWeightKg / dailyConso;
    final days = totalDays.toInt();
    final hours = ((totalDays - days) * 24).toInt();
    final emptyDate = DateTime.now().add(Duration(days: days, hours: hours));

    // Détection de micro-fuite nocturne
    bool slowLeak = false;
    for (int i = 1; i < history.length; i++) {
      final dt = DateTime.fromMillisecondsSinceEpoch(history[i].timestamp * 1000);
      if (dt.hour >= 1 && dt.hour <= 5) {
        final dw = history[i - 1].weightKg - history[i].weightKg;
        final dtHours = (history[i].timestamp - history[i - 1].timestamp) / 3600.0;
        if (dtHours > 0.5 && (dw / dtHours) > 0.020) {
          slowLeak = true;
          break;
        }
      }
    }

    String rec = "Consommation nominale optimale.";
    if (slowLeak) {
      rec = "⚠️ Suspicion de fuite lente : perte de gaz nocturne anormale observée !";
    } else if (days <= 3) {
      rec = "⚠️ Moins de 3 jours restants. Pensez à commander une recharge.";
    }

    return PredictionResult(
      daysRemaining: days,
      hoursRemaining: hours,
      displayStr: '$days j : ${hours.toString().padLeft(2, '0')} h',
      estimatedEmptyDate: DateFormat('dd/MM/yyyy').format(emptyDate),
      averageDailyConsumptionKg: dailyConso,
      confidenceHours: min(72, max(12, (totalDays * 2.5).toInt())),
      slowLeakDetected: slowLeak,
      recommendation: rec,
    );
  }
}
