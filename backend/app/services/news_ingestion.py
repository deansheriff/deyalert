from __future__ import annotations

import calendar
import hashlib
import html
import json
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

import feedparser
import geonamescache
import httpx

from app.core.config import get_settings
from app.models.advisory import (
    ArticleCandidate,
    LocationConfidence,
)
from app.models.incident import IncidentType, Location, Severity
from app.services.news_service import NewsService, get_news_service

_TRACKING_PARAMS = {
    "fbclid",
    "gclid",
    "mc_cid",
    "mc_eid",
}

_TYPE_KEYWORDS: list[tuple[IncidentType, tuple[str, ...]]] = [
    (
        IncidentType.kidnapping,
        ("kidnap", "abduct", "hostage", "ransom"),
    ),
    (
        IncidentType.armed_robbery,
        ("armed robbery", "robbers", "robbery", "gunmen attack"),
    ),
    (
        IncidentType.roadblock,
        ("roadblock", "checkpoint", "road closure", "highway blocked"),
    ),
    (
        IncidentType.cult_clash,
        ("cult clash", "cultists", "cult violence"),
    ),
    (
        IncidentType.banditry,
        ("bandit", "terrorist attack", "insurgent", "boko haram", "iswap"),
    ),
    (
        IncidentType.fire_outbreak,
        ("fire outbreak", "inferno", "explosion", "building fire", "market fire"),
    ),
    (
        IncidentType.suspicious_activity,
        (
            "security threat",
            "shooting",
            "shots fired",
            "communal clash",
            "violent clash",
            "attack",
        ),
    ),
]

_CRITICAL_KEYWORDS = (
    "mass casualty",
    "multiple fatalities",
    "many killed",
    "bomb explosion",
    "suicide bombing",
)
_HIGH_KEYWORDS = (
    "killed",
    "kidnap",
    "abduct",
    "gunmen",
    "bandit",
    "terrorist",
    "explosion",
    "inferno",
)

_STATE_CAPITALS = {
    "abia": "Umuahia",
    "adamawa": "Yola",
    "akwa ibom": "Uyo",
    "anambra": "Awka",
    "bauchi": "Bauchi",
    "bayelsa": "Yenagoa",
    "benue": "Makurdi",
    "borno": "Maiduguri",
    "cross river": "Calabar",
    "delta": "Asaba",
    "ebonyi": "Abakaliki",
    "edo": "Benin City",
    "ekiti": "Ado-Ekiti",
    "enugu": "Enugu",
    "gombe": "Gombe",
    "imo": "Owerri",
    "jigawa": "Dutse",
    "kaduna": "Kaduna",
    "kano": "Kano",
    "katsina": "Katsina",
    "kebbi": "Birnin Kebbi",
    "kogi": "Lokoja",
    "kwara": "Ilorin",
    "lagos": "Lagos",
    "nasarawa": "Lafia",
    "niger": "Minna",
    "ogun": "Abeokuta",
    "ondo": "Akure",
    "osun": "Osogbo",
    "oyo": "Ibadan",
    "plateau": "Jos",
    "rivers": "Port Harcourt",
    "sokoto": "Sokoto",
    "taraba": "Jalingo",
    "yobe": "Damaturu",
    "zamfara": "Gusau",
    "federal capital territory": "Abuja",
    "fct": "Abuja",
}


@dataclass(frozen=True)
class FeedSource:
    name: str
    url: str


@dataclass(frozen=True)
class LocationMatch:
    location: Location
    name: str
    confidence: LocationConfidence


def configured_feeds() -> list[FeedSource]:
    try:
        values = json.loads(get_settings().news_feeds_json)
    except json.JSONDecodeError as error:
        raise RuntimeError("NEWS_FEEDS_JSON must contain valid JSON") from error
    if not isinstance(values, list):
        raise RuntimeError("NEWS_FEEDS_JSON must be a JSON array")
    feeds = []
    for item in values:
        if not isinstance(item, dict) or not item.get("name") or not item.get("url"):
            raise RuntimeError("Each news feed requires name and url")
        feeds.append(FeedSource(name=str(item["name"]), url=str(item["url"])))
    return feeds


def canonical_url(value: str) -> str:
    parts = urlsplit(value)
    query = urlencode(
        [
            (key, item)
            for key, item in parse_qsl(parts.query, keep_blank_values=True)
            if not key.lower().startswith("utm_")
            and key.lower() not in _TRACKING_PARAMS
        ]
    )
    return urlunsplit(
        (
            parts.scheme.lower(),
            parts.netloc.lower(),
            parts.path,
            query,
            "",
        )
    )


def plain_text(value: str | None) -> str:
    if not value:
        return ""
    without_tags = re.sub(r"<[^>]+>", " ", value)
    return re.sub(r"\s+", " ", html.unescape(without_tags)).strip()


class SecurityClassifier:
    def classify(
        self,
        title: str,
        summary: str | None,
    ) -> tuple[IncidentType, Severity] | None:
        text_value = f"{title} {summary or ''}".lower()
        incident_type = next(
            (
                incident_type
                for incident_type, keywords in _TYPE_KEYWORDS
                if any(keyword in text_value for keyword in keywords)
            ),
            None,
        )
        if incident_type is None:
            return None
        if any(keyword in text_value for keyword in _CRITICAL_KEYWORDS):
            severity = Severity.critical
        elif any(keyword in text_value for keyword in _HIGH_KEYWORDS):
            severity = Severity.high
        else:
            severity = Severity.medium
        return incident_type, severity


class NigeriaLocationExtractor:
    def __init__(self) -> None:
        self._cities = _nigerian_cities()

    def extract(self, value: str) -> LocationMatch | None:
        text_value = value.lower()
        matches: list[tuple[int, int, str, float, float]] = []
        for name, lat, lng in self._cities:
            match = re.search(rf"(?<!\w){re.escape(name.lower())}(?!\w)", text_value)
            if match:
                matches.append((match.start(), -len(name), name, lat, lng))
        if matches:
            _, _, name, lat, lng = min(matches)
            return LocationMatch(
                location=Location(lat=lat, lng=lng),
                name=name,
                confidence=LocationConfidence.city,
            )

        city_lookup = {name.lower(): (lat, lng) for name, lat, lng in self._cities}
        for state, capital in _STATE_CAPITALS.items():
            pattern = (
                rf"(?<!\w){re.escape(state)}(?:\s+state)?(?!\w)"
                if state not in {"fct", "federal capital territory"}
                else rf"(?<!\w){re.escape(state)}(?!\w)"
            )
            if not re.search(pattern, text_value):
                continue
            coordinates = city_lookup.get(capital.lower())
            if coordinates:
                return LocationMatch(
                    location=Location(
                        lat=coordinates[0],
                        lng=coordinates[1],
                    ),
                    name=f"{state.title()} State",
                    confidence=LocationConfidence.state,
                )
        return None


@lru_cache(maxsize=1)
def _nigerian_cities() -> tuple[tuple[str, float, float], ...]:
    cache = geonamescache.GeonamesCache()
    cities = []
    for city in cache.get_cities().values():
        if city.get("countrycode") != "NG":
            continue
        name = str(city["name"]).strip()
        if len(name) < 3:
            continue
        cities.append((name, float(city["latitude"]), float(city["longitude"])))
    aliases = {
        "FCT Abuja": "Abuja",
        "Port-Harcourt": "Port Harcourt",
        "Ado Ekiti": "Ado-Ekiti",
    }
    by_name = {name.lower(): (lat, lng) for name, lat, lng in cities}
    for alias, canonical in aliases.items():
        coordinates = by_name.get(canonical.lower())
        if coordinates:
            cities.append((alias, coordinates[0], coordinates[1]))
    return tuple(sorted(cities, key=lambda item: len(item[0]), reverse=True))


class NewsIngestionPipeline:
    def __init__(
        self,
        service: NewsService | None = None,
        client: httpx.Client | None = None,
    ) -> None:
        self._service = service or get_news_service()
        self._client = client or httpx.Client(
            timeout=15,
            follow_redirects=True,
            headers={"User-Agent": "DeyAlert-News/1.0 (+security-advisories)"},
        )
        self._classifier = SecurityClassifier()
        self._locations = NigeriaLocationExtractor()

    def run(self) -> tuple[int, int]:
        processed = 0
        created = 0
        for feed in configured_feeds():
            feed_processed, feed_created = self.ingest_feed(feed)
            processed += feed_processed
            created += feed_created
        return processed, created

    def ingest_feed(self, source: FeedSource) -> tuple[int, int]:
        response = self._client.get(source.url)
        response.raise_for_status()
        if len(response.content) > 5_000_000:
            raise RuntimeError(f"Feed is too large: {source.name}")
        parsed = feedparser.parse(response.content)
        processed = 0
        created = 0
        cutoff = datetime.now(timezone.utc) - timedelta(days=7)
        for entry in parsed.entries[:100]:
            title = plain_text(entry.get("title"))
            url = canonical_url(str(entry.get("link", "")))
            if not title or not url.startswith(("https://", "http://")):
                continue
            published_at = self._published_at(entry)
            if published_at < cutoff:
                continue
            summary = plain_text(
                entry.get("summary") or entry.get("description")
            )[:1000]
            classification = self._classifier.classify(title, summary)
            if classification is None:
                continue
            location_match = self._locations.extract(f"{title} {summary}")
            content_hash = hashlib.sha256(
                f"{source.name}|{title}|{published_at.date()}".encode()
            ).hexdigest()
            candidate = ArticleCandidate(
                source_name=source.name,
                title=title,
                summary=summary or None,
                url=url,
                image_url=self._image_url(entry),
                author=plain_text(entry.get("author"))[:255] or None,
                published_at=published_at,
                content_hash=content_hash,
                type=classification[0],
                severity=classification[1],
                location=location_match.location if location_match else None,
                location_name=location_match.name if location_match else None,
                location_confidence=(
                    location_match.confidence
                    if location_match
                    else LocationConfidence.unknown
                ),
            )
            processed += 1
            if self._service.ingest(candidate):
                created += 1
        return processed, created

    @staticmethod
    def _published_at(entry: object) -> datetime:
        value = entry.get("published_parsed") or entry.get("updated_parsed")
        if value:
            return datetime.fromtimestamp(calendar.timegm(value), timezone.utc)
        return datetime.now(timezone.utc)

    @staticmethod
    def _image_url(entry: object) -> str | None:
        media = entry.get("media_content") or entry.get("media_thumbnail") or []
        if media and isinstance(media[0], dict):
            url = media[0].get("url")
            if url and str(url).startswith(("https://", "http://")):
                return str(url)
        return None
