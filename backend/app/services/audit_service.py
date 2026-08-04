from __future__ import annotations

import json
from typing import Any
from uuid import UUID

from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.security import DEMO_USER_ID


def record_audit(
    *,
    actor_id: UUID | None,
    action: str,
    entity_type: str,
    entity_id: UUID | None = None,
    metadata: dict[str, Any] | None = None,
    ip_address: str | None = None,
) -> None:
    settings = get_settings()
    if settings.use_in_memory_store or (
        settings.allow_unauthenticated_dev and actor_id == DEMO_USER_ID
    ):
        return
    with get_session_factory()() as session, session.begin():
        session.execute(
            text(
                """
                INSERT INTO audit_logs (
                  actor_id, action, entity_type, entity_id, metadata, ip_address
                ) VALUES (
                  :actor_id, :action, :entity_type, :entity_id,
                  CAST(:metadata AS jsonb), CAST(:ip_address AS inet)
                )
                """
            ),
            {
                "actor_id": actor_id,
                "action": action,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "metadata": json.dumps(metadata or {}),
                "ip_address": ip_address,
            },
        )
