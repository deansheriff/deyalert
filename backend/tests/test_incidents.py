from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_incident_corroborates_after_three_unique_users() -> None:
    created = client.post("/incidents", json={"type": "roadblock", "description": "Checkpoint on Allen Avenue", "location": {"lat": 6.6018, "lng": 3.3515}})
    assert created.status_code == 201
    incident_id = created.json()["id"]
    for _ in range(3):
        response = client.post(f"/incidents/{incident_id}/corroborate", json={"user_id": str(uuid4()), "location": {"lat": 6.602, "lng": 3.352}})
        assert response.status_code == 200
    assert response.json()["status"] == "corroborated"
    assert response.json()["corroboration_count"] == 3


def test_nearby_filter_requires_lat_and_lng_together() -> None:
    response = client.get("/incidents?lat=6.6")
    assert response.status_code == 400
