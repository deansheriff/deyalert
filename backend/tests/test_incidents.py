from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app
from app.models.incident import CorroborateRequest, IncidentCreate, Location
from app.services.incident_service import (
    InMemoryIncidentService,
    get_incident_service,
)
from app.services.profile_service import InMemoryProfileService, get_profile_service

service = InMemoryIncidentService()
profiles = InMemoryProfileService()
app.dependency_overrides[get_incident_service] = lambda: service
app.dependency_overrides[get_profile_service] = lambda: profiles
client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_incident_corroborates_after_three_unique_users() -> None:
    incident = service.create(
        IncidentCreate(
            type="roadblock",
            description="Checkpoint on Allen Avenue",
            location=Location(lat=6.6018, lng=3.3515),
        ),
        reporter_id=uuid4(),
    )
    payload = CorroborateRequest(location=Location(lat=6.602, lng=3.352))
    for _ in range(3):
        updated = service.corroborate(incident.id, uuid4(), payload)
    assert updated.status == "corroborated"
    assert updated.corroboration_count == 3


def test_nearby_filter_requires_lat_and_lng_together() -> None:
    response = client.get("/incidents?lat=6.6")
    assert response.status_code == 400


def test_create_uses_authenticated_user_identity() -> None:
    response = client.post(
        "/incidents",
        json={
            "type": "roadblock",
            "location": {"lat": 6.6018, "lng": 3.3515},
        },
    )
    assert response.status_code == 201
    assert response.json()["reporter_id"] == "00000000-0000-4000-8000-000000000001"


def test_profile_uses_server_derived_email_and_optional_phone() -> None:
    response = client.put(
        "/auth/profile",
        json={
            "name": "Adaeze Okafor",
            "email": "spoofed@example.com",
            "phone": "+2348012345678",
            "phone_verified": True,
            "state": "Lagos",
            "lga": "Ikeja",
            "ward": "Allen",
            "alert_radius_km": 5,
            "location_precision": "ward",
        },
    )
    assert response.status_code == 200
    assert response.json()["id"] == "00000000-0000-4000-8000-000000000001"
    assert response.json()["email"] == "demo@deyalert.local"
    assert response.json()["phone"] == "+2348012345678"
    assert response.json()["phone_verified"] is False


def test_profile_phone_can_be_omitted() -> None:
    response = client.put(
        "/auth/profile",
        json={
            "name": "Chinedu Okafor",
            "state": "Lagos",
            "lga": "Ikeja",
            "ward": "Alausa",
            "alert_radius_km": 5,
            "location_precision": "ward",
        },
    )
    assert response.status_code == 200
    assert response.json()["phone"] is None
