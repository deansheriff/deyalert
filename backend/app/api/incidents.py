from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Request, status

from app.core.security import CurrentUser, get_current_user
from app.models.incident import (
    CorroborateRequest,
    FlagRequest,
    Incident,
    IncidentCreate,
    IncidentList,
    IncidentStatus,
    Location,
)
from app.services.incident_service import IncidentService, get_incident_service
from app.services.audit_service import record_audit
from app.services.notification_service import dispatch_incident_notification

router = APIRouter(prefix="/incidents", tags=["incidents"])
Service = Annotated[IncidentService, Depends(get_incident_service)]
User = Annotated[CurrentUser, Depends(get_current_user)]


@router.post("", response_model=Incident, status_code=status.HTTP_201_CREATED)
def create_incident(
    payload: IncidentCreate,
    service: Service,
    user: User,
    request: Request,
    background_tasks: BackgroundTasks,
) -> Incident:
    incident = service.create(payload, reporter_id=user.id)
    record_audit(
        actor_id=user.id,
        action="incident.create",
        entity_type="incident",
        entity_id=incident.id,
        metadata={"client_report_id": str(payload.client_report_id)},
        ip_address=request.client.host if request.client else None,
    )
    background_tasks.add_task(dispatch_incident_notification, incident)
    return incident


@router.get("", response_model=IncidentList)
def list_incidents(
    service: Service,
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    radius: float = Query(default=5.0, gt=0, le=50),
    type: str | None = None,
    status: IncidentStatus | None = None,
) -> IncidentList:
    if (lat is None) != (lng is None):
        raise HTTPException(status_code=400, detail="lat and lng must be provided together")
    center = Location(lat=lat, lng=lng) if lat is not None and lng is not None else None
    items = service.list(
        center=center,
        radius_km=radius,
        type_filter=type,
        status=status,
    )
    return IncidentList(items=items, total=len(items))


@router.get("/{incident_id}", response_model=Incident)
def get_incident(incident_id: UUID, service: Service) -> Incident:
    incident = service.get(incident_id)
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    return incident


@router.post("/{incident_id}/corroborate", response_model=Incident)
def corroborate(
    incident_id: UUID,
    payload: CorroborateRequest,
    service: Service,
    user: User,
    request: Request,
) -> Incident:
    try:
        incident = service.corroborate(incident_id, user.id, payload)
        record_audit(
            actor_id=user.id,
            action="incident.corroborate",
            entity_type="incident",
            entity_id=incident_id,
            ip_address=request.client.host if request.client else None,
        )
        return incident
    except KeyError:
        raise HTTPException(status_code=404, detail="Incident not found") from None
    except ValueError as error:
        raise HTTPException(status_code=403, detail=str(error)) from None


@router.post("/{incident_id}/flag", response_model=Incident)
def flag(
    incident_id: UUID,
    payload: FlagRequest,
    service: Service,
    user: User,
    request: Request,
) -> Incident:
    try:
        incident = service.flag(incident_id, user.id, payload)
        record_audit(
            actor_id=user.id,
            action="incident.flag",
            entity_type="incident",
            entity_id=incident_id,
            metadata={"reason": payload.reason},
            ip_address=request.client.host if request.client else None,
        )
        return incident
    except KeyError:
        raise HTTPException(status_code=404, detail="Incident not found") from None
