from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.models.advisory import (
    AdvisorySource,
    AdvisoryStatus,
    ArticleCandidate,
    SecurityAdvisory,
)
from app.models.incident import Location
from app.services.incident_service import distance_km

_STOP_WORDS = {
    "about",
    "after",
    "again",
    "against",
    "amid",
    "from",
    "into",
    "nigeria",
    "nigerian",
    "over",
    "security",
    "that",
    "their",
    "this",
    "with",
}


def _title_tokens(value: str) -> set[str]:
    return {
        token
        for token in re.findall(r"[a-z0-9]+", value.lower())
        if len(token) >= 4 and token not in _STOP_WORDS
    }


def title_similarity(left: str, right: str) -> float:
    left_tokens = _title_tokens(left)
    right_tokens = _title_tokens(right)
    if not left_tokens or not right_tokens:
        return 0
    return len(left_tokens & right_tokens) / len(left_tokens | right_tokens)


def advisory_trend_score(advisory: SecurityAdvisory) -> float:
    severity_weight = {
        "low": 0,
        "medium": 2,
        "high": 5,
        "critical": 8,
    }[advisory.severity.value]
    age_hours = max(
        0,
        (datetime.now(timezone.utc) - advisory.last_updated_at).total_seconds()
        / 3600,
    )
    recency = max(0, 3 - (age_hours / 24))
    return round(
        advisory.source_count * 3
        + advisory.article_count
        + severity_weight
        + recency,
        2,
    )


class NewsService(Protocol):
    def ingest(self, candidate: ArticleCandidate) -> bool: ...

    def list(
        self,
        center: Location | None = None,
        radius_km: float = 50,
    ) -> list[SecurityAdvisory]: ...

    def trending(self, limit: int = 20) -> list[SecurityAdvisory]: ...

    def pending(self, limit: int = 50) -> list[SecurityAdvisory]: ...

    def get(self, advisory_id: UUID) -> SecurityAdvisory | None: ...

    def review(
        self,
        advisory_id: UUID,
        status: AdvisoryStatus,
        reviewer_id: UUID,
    ) -> SecurityAdvisory | None: ...


class InMemoryNewsService:
    def __init__(self) -> None:
        self._advisories: dict[UUID, SecurityAdvisory] = {}
        self._article_urls: set[str] = set()

    def ingest(self, candidate: ArticleCandidate) -> bool:
        if candidate.url in self._article_urls:
            return False
        self._article_urls.add(candidate.url)

        advisory = self._find_cluster(candidate)
        source = AdvisorySource(
            source_name=candidate.source_name,
            title=candidate.title,
            url=candidate.url,
            published_at=candidate.published_at,
        )
        now = datetime.now(timezone.utc)
        if advisory:
            source_names = {item.source_name for item in advisory.sources}
            advisory.sources.append(source)
            advisory.article_count += 1
            advisory.source_count = len(source_names | {candidate.source_name})
            advisory.last_updated_at = now
            advisory.expires_at = now + timedelta(
                hours=get_settings().news_advisory_ttl_hours
            )
            advisory.trend_score = advisory_trend_score(advisory)
            return True

        auto_publish = (
            get_settings().news_auto_publish
            and candidate.location_confidence.value in {"exact", "city"}
        )
        advisory = SecurityAdvisory(
            title=candidate.title,
            summary=candidate.summary,
            type=candidate.type,
            severity=candidate.severity,
            location=candidate.location,
            location_name=candidate.location_name,
            location_confidence=candidate.location_confidence,
            status=(
                AdvisoryStatus.published
                if auto_publish
                else AdvisoryStatus.pending
            ),
            first_published_at=candidate.published_at,
            last_updated_at=now,
            expires_at=now
            + timedelta(hours=get_settings().news_advisory_ttl_hours),
            sources=[source],
        )
        advisory.trend_score = advisory_trend_score(advisory)
        self._advisories[advisory.id] = advisory
        return True

    def _find_cluster(
        self,
        candidate: ArticleCandidate,
    ) -> SecurityAdvisory | None:
        for advisory in self._advisories.values():
            if advisory.type != candidate.type:
                continue
            if abs(
                (candidate.published_at - advisory.first_published_at).total_seconds()
            ) > 48 * 3600:
                continue
            if advisory.location and candidate.location:
                if (
                    distance_km(advisory.location, candidate.location)
                    > get_settings().news_cluster_radius_km
                ):
                    continue
            elif advisory.location != candidate.location:
                continue
            if title_similarity(advisory.title, candidate.title) >= 0.25:
                return advisory
        return None

    def list(
        self,
        center: Location | None = None,
        radius_km: float = 50,
    ) -> list[SecurityAdvisory]:
        now = datetime.now(timezone.utc)
        results = []
        for advisory in self._advisories.values():
            if advisory.status != AdvisoryStatus.published:
                continue
            if advisory.expires_at <= now:
                continue
            if center:
                if advisory.location is None:
                    continue
                distance = distance_km(center, advisory.location)
                if distance > radius_km:
                    continue
                advisory = advisory.model_copy(update={"distance_km": distance})
            advisory.trend_score = advisory_trend_score(advisory)
            results.append(advisory)
        return sorted(
            results,
            key=lambda item: item.last_updated_at,
            reverse=True,
        )

    def trending(self, limit: int = 20) -> list[SecurityAdvisory]:
        results = self.list()
        return sorted(
            results,
            key=advisory_trend_score,
            reverse=True,
        )[:limit]

    def pending(self, limit: int = 50) -> list[SecurityAdvisory]:
        return sorted(
            (
                item
                for item in self._advisories.values()
                if item.status == AdvisoryStatus.pending
            ),
            key=lambda item: item.last_updated_at,
            reverse=True,
        )[:limit]

    def get(self, advisory_id: UUID) -> SecurityAdvisory | None:
        advisory = self._advisories.get(advisory_id)
        if (
            not advisory
            or advisory.status != AdvisoryStatus.published
            or advisory.expires_at <= datetime.now(timezone.utc)
        ):
            return None
        return advisory

    def review(
        self,
        advisory_id: UUID,
        status: AdvisoryStatus,
        reviewer_id: UUID,
    ) -> SecurityAdvisory | None:
        advisory = self._advisories.get(advisory_id)
        if advisory is None:
            return None
        advisory.status = status
        advisory.last_updated_at = datetime.now(timezone.utc)
        return advisory


_SOURCE_SUBQUERY = """
    COALESCE(
      (
        SELECT json_agg(
          json_build_object(
            'source_name', article.source_name,
            'title', article.title,
            'url', article.url,
            'published_at', article.published_at
          )
          ORDER BY article.published_at DESC
        )
        FROM advisory_sources link
        JOIN news_articles article ON article.id = link.article_id
        WHERE link.advisory_id = advisory.id
      ),
      '[]'::json
    ) AS sources
"""

_SELECT_COLUMNS = f"""
    advisory.id, advisory.title, advisory.summary, advisory.type,
    advisory.severity, advisory.location_name, advisory.location_confidence,
    advisory.status, advisory.source_count, advisory.article_count,
    advisory.first_published_at, advisory.last_updated_at,
    advisory.expires_at,
    CASE WHEN advisory.location IS NULL THEN NULL
         ELSE ST_Y(advisory.location::geometry) END AS lat,
    CASE WHEN advisory.location IS NULL THEN NULL
         ELSE ST_X(advisory.location::geometry) END AS lng,
    {_SOURCE_SUBQUERY}
"""


def _row_to_advisory(row: object) -> SecurityAdvisory:
    values = dict(row._mapping)  # type: ignore[attr-defined]
    lat = values.pop("lat")
    lng = values.pop("lng")
    values["location"] = (
        {"lat": lat, "lng": lng}
        if lat is not None and lng is not None
        else None
    )
    values["sources"] = values.get("sources") or []
    advisory = SecurityAdvisory.model_validate(values)
    advisory.trend_score = advisory_trend_score(advisory)
    return advisory


class DatabaseNewsService:
    def ingest(self, candidate: ArticleCandidate) -> bool:
        settings = get_settings()
        values = candidate.model_dump(mode="json")
        location = values.pop("location")
        with get_session_factory()() as session, session.begin():
            article_id = session.execute(
                text(
                    """
                    INSERT INTO news_articles (
                      id, source_name, title, summary, url, image_url, author,
                      published_at, content_hash
                    ) VALUES (
                      :id, :source_name, :title, :summary, :url, :image_url,
                      :author, :published_at, :content_hash
                    )
                    ON CONFLICT (url) DO NOTHING
                    RETURNING id
                    """
                ),
                {
                    **values,
                    "id": uuid4(),
                },
            ).scalar_one_or_none()
            if article_id is None:
                return False

            params: dict[str, object] = {
                "type": candidate.type.value,
                "published_at": candidate.published_at,
            }
            location_clause = "advisory.location IS NULL"
            if location:
                location_clause = """
                    advisory.location IS NOT NULL AND ST_DWithin(
                      advisory.location,
                      ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                      :cluster_radius_m
                    )
                """
                params.update(
                    {
                        "lat": location["lat"],
                        "lng": location["lng"],
                        "cluster_radius_m": settings.news_cluster_radius_km
                        * 1000,
                    }
                )
            rows = session.execute(
                text(
                    f"""
                    SELECT advisory.id, advisory.title
                    FROM security_advisories advisory
                    WHERE advisory.type = :type
                      AND advisory.status IN ('pending', 'published')
                      AND ABS(
                        EXTRACT(EPOCH FROM (
                          advisory.first_published_at - CAST(:published_at AS timestamptz)
                        ))
                      ) <= 172800
                      AND {location_clause}
                    ORDER BY advisory.last_updated_at DESC
                    LIMIT 25
                    """
                ),
                params,
            ).all()
            cluster = max(
                (
                    (row.id, title_similarity(row.title, candidate.title))
                    for row in rows
                ),
                key=lambda item: item[1],
                default=(None, 0),
            )

            if cluster[0] is None or cluster[1] < 0.25:
                advisory_id = uuid4()
                auto_publish = (
                    settings.news_auto_publish
                    and candidate.location_confidence.value in {"exact", "city"}
                )
                expires_at = datetime.now(timezone.utc) + timedelta(
                    hours=settings.news_advisory_ttl_hours
                )
                session.execute(
                    text(
                        """
                        INSERT INTO security_advisories (
                          id, title, summary, type, severity, location,
                          location_name, location_confidence, status,
                          first_published_at, expires_at
                        ) VALUES (
                          :id, :title, :summary, :type, :severity,
                          CASE WHEN :lat IS NULL THEN NULL ELSE
                            ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
                          END,
                          :location_name, :location_confidence, :status,
                          :published_at, :expires_at
                        )
                        """
                    ),
                    {
                        "id": advisory_id,
                        "title": candidate.title,
                        "summary": candidate.summary,
                        "type": candidate.type.value,
                        "severity": candidate.severity.value,
                        "lat": location["lat"] if location else None,
                        "lng": location["lng"] if location else None,
                        "location_name": candidate.location_name,
                        "location_confidence": candidate.location_confidence.value,
                        "status": "published" if auto_publish else "pending",
                        "published_at": candidate.published_at,
                        "expires_at": expires_at,
                    },
                )
            else:
                advisory_id = cluster[0]

            session.execute(
                text(
                    """
                    INSERT INTO advisory_sources (advisory_id, article_id)
                    VALUES (:advisory_id, :article_id)
                    ON CONFLICT DO NOTHING
                    """
                ),
                {"advisory_id": advisory_id, "article_id": article_id},
            )
            session.execute(
                text(
                    """
                    UPDATE security_advisories advisory
                    SET article_count = (
                          SELECT COUNT(*) FROM advisory_sources
                          WHERE advisory_id = advisory.id
                        ),
                        source_count = (
                          SELECT COUNT(DISTINCT article.source_name)
                          FROM advisory_sources link
                          JOIN news_articles article ON article.id = link.article_id
                          WHERE link.advisory_id = advisory.id
                        ),
                        last_updated_at = NOW(),
                        expires_at = NOW() + make_interval(hours => :ttl_hours)
                    WHERE advisory.id = :advisory_id
                    """
                ),
                {
                    "advisory_id": advisory_id,
                    "ttl_hours": settings.news_advisory_ttl_hours,
                },
            )
            return True

    def list(
        self,
        center: Location | None = None,
        radius_km: float = 50,
    ) -> list[SecurityAdvisory]:
        clauses = [
            "advisory.status = 'published'",
            "advisory.expires_at > NOW()",
        ]
        params: dict[str, object] = {}
        distance_column = ""
        if center:
            clauses.extend(
                [
                    "advisory.location IS NOT NULL",
                    """
                    ST_DWithin(
                      advisory.location,
                      ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                      :radius_m
                    )
                    """,
                ]
            )
            params.update(
                {
                    "lat": center.lat,
                    "lng": center.lng,
                    "radius_m": radius_km * 1000,
                }
            )
            distance_column = """
                , ST_Distance(
                    advisory.location,
                    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
                  ) / 1000 AS distance_km
            """
        rows = self._select(
            f"""
            WHERE {" AND ".join(clauses)}
            ORDER BY advisory.last_updated_at DESC
            LIMIT 200
            """,
            params,
            distance_column,
        )
        return rows

    def trending(self, limit: int = 20) -> list[SecurityAdvisory]:
        items = self.list()
        return sorted(
            items,
            key=advisory_trend_score,
            reverse=True,
        )[:limit]

    def pending(self, limit: int = 50) -> list[SecurityAdvisory]:
        return self._select(
            """
            WHERE advisory.status = 'pending'
            ORDER BY advisory.last_updated_at DESC
            LIMIT :limit
            """,
            {"limit": limit},
        )

    def get(self, advisory_id: UUID) -> SecurityAdvisory | None:
        rows = self._select(
            """
            WHERE advisory.id = :advisory_id
              AND advisory.status = 'published'
              AND advisory.expires_at > NOW()
            LIMIT 1
            """,
            {"advisory_id": advisory_id},
        )
        return rows[0] if rows else None

    def review(
        self,
        advisory_id: UUID,
        status: AdvisoryStatus,
        reviewer_id: UUID,
    ) -> SecurityAdvisory | None:
        with get_session_factory()() as session, session.begin():
            updated = session.execute(
                text(
                    """
                    UPDATE security_advisories
                    SET status = :status,
                        reviewed_by = :reviewer_id,
                        reviewed_at = NOW(),
                        last_updated_at = NOW()
                    WHERE id = :advisory_id
                    RETURNING id
                    """
                ),
                {
                    "advisory_id": advisory_id,
                    "status": status.value,
                    "reviewer_id": reviewer_id,
                },
            ).scalar_one_or_none()
        if updated is None:
            return None
        rows = self._select(
            "WHERE advisory.id = :advisory_id LIMIT 1",
            {"advisory_id": advisory_id},
        )
        return rows[0] if rows else None

    def _select(
        self,
        suffix: str,
        params: dict[str, object],
        extra_columns: str = "",
    ) -> list[SecurityAdvisory]:
        statement = text(
            f"""
            SELECT {_SELECT_COLUMNS} {extra_columns}
            FROM security_advisories advisory
            {suffix}
            """
        )
        with get_session_factory()() as session:
            rows = session.execute(statement, params).all()
            return [
                _row_to_advisory(row).model_copy(
                    update={
                        "distance_km": getattr(row, "distance_km", None),
                    }
                )
                for row in rows
            ]


_in_memory_service = InMemoryNewsService()
_database_service = DatabaseNewsService()


def get_news_service() -> NewsService:
    if get_settings().use_in_memory_store:
        return _in_memory_service
    return _database_service
