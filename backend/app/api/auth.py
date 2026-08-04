from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException

from app.core.security import CurrentUser, get_current_user
from app.models.user import ProfileUpdate, UserProfile
from app.services.profile_service import ProfileService, get_profile_service

router = APIRouter(prefix="/auth", tags=["auth"])
User = Annotated[CurrentUser, Depends(get_current_user)]
Profiles = Annotated[ProfileService, Depends(get_profile_service)]


@router.get("/me", response_model=UserProfile)
def me(user: User, profiles: Profiles) -> UserProfile:
    profile = profiles.get(user.id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile setup required")
    return profile


@router.put("/profile", response_model=UserProfile)
def update_profile(
    payload: ProfileUpdate,
    user: User,
    profiles: Profiles,
) -> UserProfile:
    try:
        return profiles.upsert(user, payload)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from None
