from __future__ import annotations

import re

import httpx
from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.models.incident import Incident
from app.core.security import DEMO_USER_ID


def dispatch_incident_notification(incident: Incident) -> None:
    settings = get_settings()
    if settings.allow_unauthenticated_dev and incident.reporter_id == DEMO_USER_ID:
        return
    if not settings.use_in_memory_store and incident.lga:
        with get_session_factory()() as session, session.begin():
            session.execute(
                text(
                    """
                    INSERT INTO notifications (
                      user_id, incident_id, title, body, severity
                    )
                    SELECT id, :incident_id, :title, :body, :severity
                    FROM users
                    WHERE is_active = true AND lga = :lga
                      AND (:ward IS NULL OR ward = :ward)
                      AND id <> :reporter_id
                    """
                ),
                {
                    "incident_id": incident.id,
                    "title": f"New {incident.type.value.replace('_', ' ')} report",
                    "body": f"Reported near {incident.location_name or incident.lga}",
                    "severity": incident.severity.value,
                    "lga": incident.lga,
                    "ward": incident.ward,
                    "reporter_id": incident.reporter_id,
                },
            )

    if not settings.ntfy_base_url or not settings.ntfy_topic:
        return
    area = re.sub(r"[^a-z0-9]+", "-", (incident.lga or "nigeria").lower()).strip("-")
    topic = f"{settings.ntfy_topic}-{area}"
    try:
        headers = (
            {"Authorization": f"Bearer {settings.ntfy_access_token}"}
            if settings.ntfy_access_token
            else None
        )
        httpx.post(
            f"{settings.ntfy_base_url.rstrip('/')}/{topic}",
            headers=headers,
            json={
                "topic": topic,
                "title": f"Dey Alert: {incident.type.value.replace('_', ' ').title()}",
                "message": f"{incident.location_name or 'Nearby area'} · {incident.status.value}",
                "priority": 5 if incident.severity.value in {"critical", "high"} else 3,
                "tags": ["warning"],
            },
            timeout=5,
        ).raise_for_status()
    except httpx.HTTPError:
        # Notification delivery is best-effort and must not roll back a report.
        return
