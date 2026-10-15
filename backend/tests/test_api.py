import pytest
from httpx import AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_health_check():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"

@pytest.mark.asyncio
async def test_get_telemetry_data():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/api/v1/data")
    assert response.status_code == 200
    data = response.json()
    assert "weight_kg" in data
    assert "level_percent" in data
    assert "gas_ppm" in data
    assert "leak" in data
    assert "valve_state" in data

@pytest.mark.asyncio
async def test_get_history():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/api/v1/history?range=day&resolution=hour")
    assert response.status_code == 200
    data = response.json()
    assert data["range"] == "day"
    assert "points" in data
    assert isinstance(data["points"], list)

@pytest.mark.asyncio
async def test_valve_control_close():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post(
            "/api/v1/devices/ESP32-SMARTGAS-8A4F/valve/control",
            json={"action": "CLOSE"}
        )
    assert response.status_code == 200
    assert response.json()["valve_state"] == "CLOSE"
