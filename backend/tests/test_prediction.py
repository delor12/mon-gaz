import pytest
from datetime import datetime, timezone
from app.services.ml_predictor import ml_predictor

def test_prediction_empty_bottle():
    res = ml_predictor.predict(
        device_id="TEST-DEV",
        current_weight_kg=0.02,
        current_level_percent=0.1,
        capacity_kg=12.5,
        history_points=[]
    )
    assert res.days_remaining == 0
    assert res.hours_remaining == 0
    assert "Vide" in res.display_str
    assert res.slow_leak_detected is False

def test_prediction_initial_phase():
    # Moins de 5 points -> mode apprentissage heuristique
    res = ml_predictor.predict(
        device_id="TEST-DEV",
        current_weight_kg=8.42,
        current_level_percent=67.36,
        capacity_kg=12.5,
        history_points=[(1700000000, 8.5), (1700003600, 8.45)]
    )
    assert res.days_remaining > 20
    assert "Estimation initiale" in res.display_str
    assert res.average_daily_consumption_kg == 0.350

def test_prediction_weighted_linear_regression():
    # Historique de 10 points avec consommation régulière de 500g / jour
    now = int(datetime.now(timezone.utc).timestamp())
    points = []
    base_weight = 12.0
    for day in range(10, 0, -1):
        ts = now - (day * 86400)
        w = base_weight - (0.5 * (10 - day))
        points.append((ts, w))

    res = ml_predictor.predict(
        device_id="TEST-DEV",
        current_weight_kg=7.0,
        current_level_percent=56.0,
        capacity_kg=12.5,
        history_points=points
    )
    # Avec 7.0 kg restant et ~0.5 kg/jour -> ~14 jours
    assert 12 <= res.days_remaining <= 16
    assert 0.45 <= res.average_daily_consumption_kg <= 0.55
    assert res.slow_leak_detected is False

def test_prediction_slow_leak_detection():
    # Simulation de baisse de masse anormale la nuit (02h00 - 04h00)
    # 1700013600 correspond à 02h00 UTC
    points = [
        (1700000000, 8.500),
        (1700007200, 8.480), # 02h00 UTC
        (1700010800, 8.440), # 03h00 UTC (-40g en 1h > 20g/h)
        (1700014400, 8.400), # 04h00 UTC (-40g en 1h)
        (1700018000, 8.360), # 05h00 UTC (-40g en 1h)
        (1700021600, 8.350),
    ]

    res = ml_predictor.predict(
        device_id="TEST-DEV",
        current_weight_kg=8.35,
        current_level_percent=66.8,
        capacity_kg=12.5,
        history_points=points
    )
    assert res.slow_leak_detected is True
    assert "micro-fuite" in res.recommendation.lower() or "perte" in res.recommendation.lower()
