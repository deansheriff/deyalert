from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.core.config import get_settings
from app.core.security import CurrentUser, get_current_user, get_user_role
from app.models.advisory import (
    AdvisoryList,
    AdvisoryReview,
    AdvisoryStatus,
    SecurityAdvisory,
)
from app.models.incident import Location
from app.services.news_service import NewsService, get_news_service
from app.services.audit_service import record_audit

router = APIRouter(tags=["security news"])
Service = Annotated[NewsService, Depends(get_news_service)]
User = Annotated[CurrentUser, Depends(get_current_user)]


def require_news_admin(user: User) -> CurrentUser:
    settings = get_settings()
    if settings.allow_unauthenticated_dev:
        return user
    allowed = {
        item.strip().lower()
        for item in settings.news_admin_emails.split(",")
        if item.strip()
    }
    if (not user.email or user.email.lower() not in allowed) and get_user_role(user) != "admin":
        raise HTTPException(status_code=403, detail="News administrator required")
    return user


Admin = Annotated[CurrentUser, Depends(require_news_admin)]


@router.get("/news/trending", response_model=AdvisoryList)
def trending_news(
    service: Service,
    limit: int = Query(default=20, ge=1, le=50),
) -> AdvisoryList:
    items = service.trending(limit)
    return AdvisoryList(items=items, total=len(items))


@router.get("/news/review-queue", response_model=AdvisoryList)
def review_queue(
    service: Service,
    _: Admin,
    limit: int = Query(default=50, ge=1, le=100),
) -> AdvisoryList:
    items = service.pending(limit)
    return AdvisoryList(items=items, total=len(items))


@router.get("/advisories", response_model=AdvisoryList)
def nearby_advisories(
    service: Service,
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    radius: float = Query(default=50, gt=0, le=500),
) -> AdvisoryList:
    if (lat is None) != (lng is None):
        raise HTTPException(status_code=400, detail="lat and lng must be provided together")
    center = Location(lat=lat, lng=lng) if lat is not None and lng is not None else None
    items = service.list(center=center, radius_km=radius)
    return AdvisoryList(items=items, total=len(items))


@router.get("/advisories/{advisory_id}", response_model=SecurityAdvisory)
def advisory_detail(
    advisory_id: UUID,
    service: Service,
) -> SecurityAdvisory:
    advisory = service.get(advisory_id)
    if advisory is None:
        raise HTTPException(status_code=404, detail="Advisory not found")
    return advisory


@router.patch("/advisories/{advisory_id}/review", response_model=SecurityAdvisory)
def review_advisory(
    advisory_id: UUID,
    payload: AdvisoryReview,
    service: Service,
    admin: Admin,
    request: Request,
) -> SecurityAdvisory:
    allowed = {
        AdvisoryStatus.published,
        AdvisoryStatus.rejected,
        AdvisoryStatus.retracted,
    }
    if payload.status not in allowed:
        raise HTTPException(status_code=400, detail="Invalid review status")
    advisory = service.review(advisory_id, payload.status, admin.id)
    if advisory is None:
        raise HTTPException(status_code=404, detail="Advisory not found")
    record_audit(
        actor_id=admin.id,
        action="advisory.review",
        entity_type="security_advisory",
        entity_id=advisory_id,
        metadata={"status": payload.status.value},
        ip_address=request.client.host if request.client else None,
    )
    return advisory
