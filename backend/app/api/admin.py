from __future__ import annotations

from typing import Annotated
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.security import CurrentUser, require_admin, require_verifier
from app.models.incident import Incident, IncidentList, ModerationRequest
from app.models.user import VerifierCreate, VerifierRecord
from app.services.audit_service import record_audit
from app.services.incident_service import IncidentService, get_incident_service

router = APIRouter(tags=["moderation"])
Service = Annotated[IncidentService, Depends(get_incident_service)]
Admin = Annotated[CurrentUser, Depends(require_admin)]
Verifier = Annotated[CurrentUser, Depends(require_verifier)]

_memory_verifiers: dict[UUID, VerifierRecord] = {}


@router.patch("/incidents/{incident_id}/verify", response_model=Incident)
def verify_incident(
    incident_id: UUID,
    service: Service,
    actor: Verifier,
    request: Request,
) -> Incident:
    try:
        incident = service.verify(incident_id, actor.id)
    except KeyError:
        raise HTTPException(status_code=404, detail="Incident not found") from None
    except PermissionError as error:
        raise HTTPException(status_code=403, detail=str(error)) from None
    record_audit(
        actor_id=actor.id,
        action="incident.verify",
        entity_type="incident",
        entity_id=incident_id,
        ip_address=request.client.host if request.client else None,
    )
    return incident


@router.get("/admin/moderation", response_model=IncidentList)
def moderation_queue(
    service: Service,
    _: Admin,
    limit: int = Query(default=100, ge=1, le=200),
) -> IncidentList:
    items = service.flagged(limit)
    return IncidentList(items=items, total=len(items))


@router.patch("/admin/incidents/{incident_id}", response_model=Incident)
def moderate_incident(
    incident_id: UUID,
    payload: ModerationRequest,
    service: Service,
    actor: Admin,
    request: Request,
) -> Incident:
    try:
        incident = service.moderate(incident_id, payload.status, actor.id)
    except KeyError:
        raise HTTPException(status_code=404, detail="Incident not found") from None
    record_audit(
        actor_id=actor.id,
        action="incident.moderate",
        entity_type="incident",
        entity_id=incident_id,
        metadata={"status": payload.status.value, "notes": payload.notes},
        ip_address=request.client.host if request.client else None,
    )
    return incident


@router.get("/admin/analytics")
def analytics(_: Admin) -> dict[str, object]:
    if get_settings().use_in_memory_store:
        service = get_incident_service()
        items = service.list()
        return {
            "total": len(items),
            "by_status": {
                status: sum(item.status.value == status for item in items)
                for status in {item.status.value for item in items}
            },
        }
    with get_session_factory()() as session:
        total = session.execute(text("SELECT COUNT(*) FROM incidents")).scalar_one()
        rows = session.execute(
            text("SELECT status, COUNT(*) AS count FROM incidents GROUP BY status")
        ).all()
        return {"total": total, "by_status": {row.status: row.count for row in rows}}


@router.get("/admin/audit-logs")
def audit_logs(
    _: Admin,
    limit: int = Query(default=100, ge=1, le=500),
) -> list[dict[str, object]]:
    if get_settings().use_in_memory_store:
        return []
    with get_session_factory()() as session:
        rows = session.execute(
            text(
                """
                SELECT id, actor_id, action, entity_type, entity_id, metadata,
                       ip_address::text AS ip_address, created_at
                FROM audit_logs ORDER BY created_at DESC LIMIT :limit
                """
            ),
            {"limit": limit},
        ).all()
    return [dict(row._mapping) for row in rows]


@router.get("/admin/verifiers", response_model=list[VerifierRecord])
def list_verifiers(_: Admin) -> list[VerifierRecord]:
    if get_settings().use_in_memory_store:
        return list(_memory_verifiers.values())
    with get_session_factory()() as session:
        rows = session.execute(
            text(
                """
                SELECT id, user_id, state, lga, ward, title, is_active
                FROM verifiers ORDER BY created_at DESC
                """
            )
        ).all()
        return [VerifierRecord.model_validate(dict(row._mapping)) for row in rows]


@router.post("/admin/verifiers", response_model=VerifierRecord, status_code=201)
def create_verifier(
    payload: VerifierCreate,
    actor: Admin,
    request: Request,
) -> VerifierRecord:
    verifier_id = uuid4()
    if get_settings().use_in_memory_store:
        record = VerifierRecord(id=verifier_id, **payload.model_dump())
        _memory_verifiers[payload.user_id] = record
    else:
        with get_session_factory()() as session, session.begin():
            row = session.execute(
                text(
                    """
                    INSERT INTO verifiers (
                      id, user_id, state, lga, ward, title, verified_by
                    ) VALUES (
                      :id, :user_id, :state, :lga, :ward, :title, :verified_by
                    )
                    ON CONFLICT (user_id) DO UPDATE SET
                      state = EXCLUDED.state, lga = EXCLUDED.lga,
                      ward = EXCLUDED.ward, title = EXCLUDED.title,
                      verified_by = EXCLUDED.verified_by, is_active = true,
                      updated_at = NOW()
                    RETURNING id, user_id, state, lga, ward, title, is_active
                    """
                ),
                {"id": verifier_id, "verified_by": actor.id, **payload.model_dump()},
            ).one()
            session.execute(
                text("UPDATE users SET role = 'verifier' WHERE id = :user_id"),
                {"user_id": payload.user_id},
            )
            record = VerifierRecord.model_validate(dict(row._mapping))
    record_audit(
        actor_id=actor.id,
        action="verifier.upsert",
        entity_type="verifier",
        entity_id=record.id,
        metadata={"user_id": str(payload.user_id), "lga": payload.lga},
        ip_address=request.client.host if request.client else None,
    )
    return record


@router.delete("/admin/verifiers/{user_id}", status_code=204)
def revoke_verifier(user_id: UUID, actor: Admin, request: Request) -> None:
    if get_settings().use_in_memory_store:
        _memory_verifiers.pop(user_id, None)
    else:
        with get_session_factory()() as session, session.begin():
            session.execute(
                text("UPDATE verifiers SET is_active = false WHERE user_id = :user_id"),
                {"user_id": user_id},
            )
            session.execute(
                text("UPDATE users SET role = 'member' WHERE id = :user_id"),
                {"user_id": user_id},
            )
    record_audit(
        actor_id=actor.id,
        action="verifier.revoke",
        entity_type="user",
        entity_id=user_id,
        ip_address=request.client.host if request.client else None,
    )
