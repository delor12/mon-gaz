from datetime import datetime, timedelta, timezone
from typing import List, Tuple, Optional
import numpy as np
from app.schemas.telemetry import PredictionResult

class MLPredictor:
    """Moteur d'intelligence artificielle de prédiction d'autonomie et détection d'anomalies."""

    @staticmethod
    def predict(
        device_id: str,
        current_weight_kg: float,
        current_level_percent: float,
        capacity_kg: float,
        history_points: List[Tuple[int, float]] # [(timestamp_s, weight_kg), ...]
    ) -> PredictionResult:
        if current_weight_kg <= 0.05:
            return PredictionResult(
                device_id=device_id,
                current_weight_kg=0.0,
                current_level_percent=0.0,
                days_remaining=0,
                hours_remaining=0,
                display_str="0 j : 00 min (Vide)",
                estimated_empty_date=datetime.now(timezone.utc).strftime("%d/%m/%Y %H:%M"),
                average_daily_consumption_kg=0.0,
                confidence_interval_hours=0,
                slow_leak_detected=False,
                recommendation="Bouteille vide. Veuillez la remplacer par une nouvelle bouteille pleine."
            )

        # Si pas assez d'historique (prototype neuf), estimation empirique par défaut
        if len(history_points) < 5:
            default_daily_conso = 0.350 # 350 grammes par jour pour un foyer moyen
            days = int(current_weight_kg / default_daily_conso)
            hours = int(((current_weight_kg / default_daily_conso) - days) * 24)
            empty_dt = datetime.now(timezone.utc) + timedelta(days=days, hours=hours)

            return PredictionResult(
                device_id=device_id,
                current_weight_kg=current_weight_kg,
                current_level_percent=current_level_percent,
                days_remaining=days,
                hours_remaining=hours,
                display_str=f"{days} j : {hours:02d} h (Estimation initiale)",
                estimated_empty_date=empty_dt.strftime("%d/%m/%Y"),
                average_daily_consumption_kg=default_daily_conso,
                confidence_interval_hours=48,
                slow_leak_detected=False,
                recommendation="Phase d'apprentissage en cours (analyse des habitudes du foyer sur 7 jours)."
            )

        # --- NIVEAU 1 : RÉGRESSION LINÉAIRE PONDÉRÉE (WLR) ---
        timestamps = np.array([p[0] for p in history_points], dtype=np.float64)
        weights = np.array([p[1] for p in history_points], dtype=np.float64)

        t_max = np.max(timestamps)
        # Pondération exponentielle des points les plus récents (demi-vie de 3 jours)
        lambda_decay = np.log(2.0) / (3.0 * 86400.0)
        weights_w = np.exp(-lambda_decay * (t_max - timestamps))

        t_norm = (timestamps - np.min(timestamps)) # Secondes normalisées
        w_sum = np.sum(weights_w)
        t_mean = np.sum(weights_w * t_norm) / w_sum
        y_mean = np.sum(weights_w * weights) / w_sum

        numerator = np.sum(weights_w * (t_norm - t_mean) * (weights - y_mean))
        denominator = np.sum(weights_w * (t_norm - t_mean) ** 2)

        if denominator != 0:
            slope_kg_per_sec = numerator / denominator
        else:
            slope_kg_per_sec = -0.350 / 86400.0

        # Consommation journalière positive
        daily_consumption = max(0.080, -slope_kg_per_sec * 86400.0) # Au minimum 80g/jour

        # --- NIVEAU 2 : MODÉLISATION DE LA DATE D'ÉPUISEMENT ---
        total_days_remaining = current_weight_kg / daily_consumption
        days = int(total_days_remaining)
        hours = int((total_days_remaining - days) * 24)

        empty_date = datetime.now(timezone.utc) + timedelta(days=days, hours=hours)
        confidence_hours = min(72, max(12, int(total_days_remaining * 2.5)))

        # --- DÉTECTION D'ANOMALIE : MICRO-FUITE LENTE ---
        slow_leak = False
        night_deltas = []
        for i in range(1, len(history_points)):
            ts = datetime.fromtimestamp(history_points[i][0], tz=timezone.utc)
            if 1 <= ts.hour <= 5: # Entre 01h00 et 05h00 du matin
                dw = history_points[i-1][1] - history_points[i][1]
                dt_h = (history_points[i][0] - history_points[i-1][0]) / 3600.0
                if dt_h > 0.5:
                    rate = dw / dt_h
                    if rate > 0.020: # Perte nocturne > 20 g/h
                        night_deltas.append(rate)

        if len(night_deltas) >= 3:
            slow_leak = True

        recom = "Consommation nominale optimale."
        if slow_leak:
            recom = "⚠️ ALERTE : Baisse continue de masse observée la nuit sans utilisation. Vérifiez les raccords du détendeur !"
        elif days <= 3:
            recom = "⚠️ Commande urgente recommandée : moins de 3 jours d'autonomie restante."
        elif days <= 7:
            recom = "Anticipez le remplacement de la bouteille dans le courant de la semaine."

        return PredictionResult(
            device_id=device_id,
            current_weight_kg=round(current_weight_kg, 2),
            current_level_percent=round(current_level_percent, 1),
            days_remaining=days,
            hours_remaining=hours,
            display_str=f"{days} j : {hours:02d} h",
            estimated_empty_date=empty_date.strftime("%d/%m/%Y"),
            average_daily_consumption_kg=round(daily_consumption, 3),
            confidence_interval_hours=confidence_hours,
            slow_leak_detected=slow_leak,
            recommendation=recom
        )

ml_predictor = MLPredictor()
