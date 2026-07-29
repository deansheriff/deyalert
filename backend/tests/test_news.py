from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi.testclient import TestClient

from app.main import app
from app.models.advisory import (
    AdvisoryStatus,
    ArticleCandidate,
    LocationConfidence,
)
from app.models.incident import IncidentType, Location, Severity
from app.services.news_ingestion import (
    NigeriaLocationExtractor,
    SecurityClassifier,
    canonical_url,
)
from app.services.news_service import InMemoryNewsService, get_news_service

service = InMemoryNewsService()
app.dependency_overrides[get_news_service] = lambda: service
client = TestClient(app)


def candidate(
    *,
    source: str,
    title: str,
    url: str,
) -> ArticleCandidate:
    return ArticleCandidate(
        source_name=source,
        title=title,
        summary="Residents were advised to avoid the affected area.",
        url=url,
        published_at=datetime.now(timezone.utc),
        content_hash=url.rsplit("/", 1)[-1].ljust(64, "0")[:64],
        type=IncidentType.banditry,
        severity=Severity.high,
        location=Location(lat=11.8333, lng=13.15),
        location_name="Maiduguri",
        location_confidence=LocationConfidence.city,
    )


def test_classifier_rejects_general_news_and_maps_security_type() -> None:
    classifier = SecurityClassifier()
    assert classifier.classify("Nigeria announces new trade policy", None) is None
    result = classifier.classify(
        "Bandits attack community in Kaduna",
        "Security forces responded.",
    )
    assert result == (IncidentType.banditry, Severity.high)


def test_location_extractor_finds_nigerian_city() -> None:
    result = NigeriaLocationExtractor().extract(
        "Security forces respond to attack in Maiduguri"
    )
    assert result is not None
    assert result.name == "Maiduguri"
    assert result.confidence == LocationConfidence.city


def test_tracking_parameters_are_removed_from_article_urls() -> None:
    assert canonical_url(
        "https://example.com/story?utm_source=x&id=2#section"
    ) == "https://example.com/story?id=2"


def test_reviewed_advisory_appears_in_trending_and_nearby_results() -> None:
    first = candidate(
        source="Outlet One",
        title="Bandits attack community near Maiduguri",
        url="https://one.example/security-story",
    )
    second = candidate(
        source="Outlet Two",
        title="Community near Maiduguri attacked by bandits",
        url="https://two.example/security-story",
    )
    assert service.ingest(first) is True
    assert service.ingest(second) is True
    assert service.ingest(second) is False

    pending = client.get("/news/review-queue")
    assert pending.status_code == 200
    advisory = pending.json()["items"][0]
    assert advisory["source_count"] == 2
    assert advisory["article_count"] == 2

    reviewed = client.patch(
        f"/advisories/{advisory['id']}/review",
        json={"status": AdvisoryStatus.published.value},
    )
    assert reviewed.status_code == 200

    trending = client.get("/news/trending")
    assert trending.status_code == 200
    assert trending.json()["total"] == 1
    assert trending.json()["items"][0]["status"] == "published"

    nearby = client.get("/advisories?lat=11.84&lng=13.16&radius=10")
    assert nearby.status_code == 200
    assert nearby.json()["total"] == 1


def test_expired_advisory_is_not_returned() -> None:
    expired_service = InMemoryNewsService()
    item = candidate(
        source="Outlet Three",
        title="Bandits attack another Maiduguri community",
        url="https://three.example/security-story",
    )
    expired_service.ingest(item)
    advisory = expired_service.pending()[0]
    expired_service.review(
        advisory.id,
        AdvisoryStatus.published,
        UUID("00000000-0000-4000-8000-000000000001"),
    )
    advisory.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
    assert expired_service.trending() == []
