from __future__ import annotations

from typing import Annotated
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.security import CurrentUser, get_current_user
from app.models.incident import IncidentCreate, IncidentType, Severity
from app.models.sos import (
    SosAlert,
    SosCreate,
    SosReadiness,
    TrustedContact,
    TrustedContactCreate,
)
from app.services.audit_service import record_audit
from app.services.incident_service import IncidentService, get_incident_service
from app.services.sms_service import send_sms, sms_is_configured

router = APIRouter(tags=["sos"])
User = Annotated[CurrentUser, Depends(get_current_user)]
Service = Annotated[IncidentService, Depends(get_incident_service)]

_memory_contacts: dict[UUID, dict[UUID, TrustedContact]] = {}
_memory_alerts: dict[tuple[UUID, UUID], SosAlert] = {}


def _contacts(user_id: UUID) -> list[TrustedContact]:
    if get_settings().use_in_memory_store:
        return list(_memory_contacts.get(user_id, {}).values())
    with get_session_factory()() as session:
        rows = session.execute(
            text(
                """
                SELECT id, user_id, name, phone, relationship
                FROM trusted_contacts WHERE user_id = :user_id
                ORDER BY created_at
                """
            ),
            {"user_id": user_id},
        ).all()
        return [TrustedContact.model_validate(dict(row._mapping)) for row in rows]


@router.get("/trusted-contacts", response_model=list[TrustedContact])
def list_contacts(user: User) -> list[TrustedContact]:
    return _contacts(user.id)


@router.post("/trusted-contacts", response_model=TrustedContact, status_code=201)
def add_contact(
    payload: TrustedContactCreate,
    user: User,
    request: Request,
) -> TrustedContact:
    contact = TrustedContact(user_id=user.id, **payload.model_dump())
    if get_settings().use_in_memory_store:
        _memory_contacts.setdefault(user.id, {})[contact.id] = contact
    else:
        with get_session_factory()() as session, session.begin():
            session.execute(
                text(
                    """
                    INSERT INTO trusted_contacts (
                      id, user_id, name, phone, relationship
                    ) VALUES (:id, :user_id, :name, :phone, :relationship)
                    """
                ),
                contact.model_dump(mode="json"),
            )
    record_audit(
        actor_id=user.id,
        action="trusted_contact.create",
        entity_type="trusted_contact",
        entity_id=contact.id,
        ip_address=request.client.host if request.client else None,
    )
    return contact


@router.delete("/trusted-contacts/{contact_id}", status_code=204)
def delete_contact(contact_id: UUID, user: User, request: Request) -> None:
    if get_settings().use_in_memory_store:
        _memory_contacts.get(user.id, {}).pop(contact_id, None)
    else:
        with get_session_factory()() as session, session.begin():
            session.execute(
                text(
                    "DELETE FROM trusted_contacts WHERE id = :id AND user_id = :user_id"
                ),
                {"id": contact_id, "user_id": user.id},
            )
    record_audit(
        actor_id=user.id,
        action="trusted_contact.delete",
        entity_type="trusted_contact",
        entity_id=contact_id,
        ip_address=request.client.host if request.client else None,
    )


@router.get("/sos/readiness", response_model=SosReadiness)
def sos_readiness(user: User) -> SosReadiness:
    contact_count = len(_contacts(user.id))
    configured = sms_is_configured()
    ready = contact_count > 0 and configured
    return SosReadiness(
        ready=ready,
        contact_count=contact_count,
        sms_provider=get_settings().sms_provider,
        message=(
            "SOS is ready"
            if ready
            else "Add a trusted contact" if contact_count == 0 else "SMS is not configured"
        ),
    )


@router.post("/sos", response_model=SosAlert, status_code=201)
def trigger_sos(
    payload: SosCreate,
    user: User,
    service: Service,
    request: Request,
) -> SosAlert:
    existing_memory = _memory_alerts.get((user.id, payload.client_alert_id))
    if get_settings().use_in_memory_store and existing_memory:
        return existing_memory
    contacts = _contacts(user.id)
    if not contacts:
        raise HTTPException(status_code=409, detail="Add a trusted contact first")
    if not sms_is_configured():
        raise HTTPException(status_code=503, detail="SOS SMS delivery is not configured")

    if get_settings().use_in_memory_store:
        lga = "Pilot area"
        ward = "Pilot ward"
    else:
        with get_session_factory()() as session:
            profile = session.execute(
                text("SELECT lga, ward FROM users WHERE id = :user_id"),
                {"user_id": user.id},
            ).one_or_none()
        if profile is None:
            raise HTTPException(status_code=409, detail="Complete profile setup first")
        lga, ward = profile.lga, profile.ward

    incident = service.create(
        IncidentCreate(
            client_report_id=payload.client_alert_id,
            type=IncidentType.other,
            description="Emergency SOS triggered. Details withheld for user safety.",
            location=payload.location,
            location_name=f"{ward}, {lga}",
            lga=lga,
            ward=ward,
            severity=Severity.critical,
            is_anonymous=True,
        ),
        reporter_id=user.id,
    )
    maps_url = f"https://maps.google.com/?q={payload.location.lat},{payload.location.lng}"
    message = f"Dey Alert SOS: a trusted contact needs help. Location: {maps_url}"
    alert_id = uuid4()
    if not get_settings().use_in_memory_store:
        with get_session_factory()() as session, session.begin():
            inserted = session.execute(
                text(
                    """
                    INSERT INTO sos_alerts (
                      id, user_id, client_alert_id, location, incident_id, sms_sent_to
                    ) VALUES (
                      :id, :user_id, :client_alert_id,
                      ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                      :incident_id, :delivered
                    )
                    ON CONFLICT (user_id, client_alert_id) DO NOTHING
                    RETURNING id
                    """
                ),
                {
                    "id": alert_id,
                    "user_id": user.id,
                    "client_alert_id": payload.client_alert_id,
                    "lat": payload.location.lat,
                    "lng": payload.location.lng,
                    "incident_id": incident.id,
                    "delivered": [],
                },
            ).scalar_one_or_none()
        if inserted is None:
            with get_session_factory()() as session:
                existing = session.execute(
                    text(
                        """
                        SELECT id, incident_id, status, sms_sent_to, triggered_at
                        FROM sos_alerts
                        WHERE user_id = :user_id AND client_alert_id = :client_alert_id
                        """
                    ),
                    {"user_id": user.id, "client_alert_id": payload.client_alert_id},
                ).one()
            return SosAlert(
                id=existing.id,
                user_id=user.id,
                incident_id=existing.incident_id,
                status=existing.status,
                delivered_to=len(existing.sms_sent_to or []),
                contact_count=len(contacts),
                triggered_at=existing.triggered_at,
            )

    delivered = [contact.phone for contact in contacts if send_sms(contact.phone, message)]
    if not get_settings().use_in_memory_store:
        with get_session_factory()() as session, session.begin():
            session.execute(
                text("UPDATE sos_alerts SET sms_sent_to = :delivered WHERE id = :id"),
                {"id": alert_id, "delivered": delivered},
            )
    record_audit(
        actor_id=user.id,
        action="sos.trigger",
        entity_type="sos_alert",
        entity_id=alert_id,
        metadata={"contact_count": len(contacts), "delivered_to": len(delivered)},
        ip_address=request.client.host if request.client else None,
    )
    alert = SosAlert(
        id=alert_id,
        user_id=user.id,
        incident_id=incident.id,
        delivered_to=len(delivered),
        contact_count=len(contacts),
    )
    if get_settings().use_in_memory_store:
        _memory_alerts[(user.id, payload.client_alert_id)] = alert
    return alert
