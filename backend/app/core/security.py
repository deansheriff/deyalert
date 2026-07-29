from dataclasses import dataclass
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.core.config import get_settings

bearer = HTTPBearer(auto_error=False)
DEMO_USER_ID = UUID("00000000-0000-4000-8000-000000000001")


@dataclass(frozen=True)
class CurrentUser:
    id: UUID
    phone: str


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> CurrentUser:
    settings = get_settings()
    if credentials is None:
        if settings.allow_unauthenticated_dev:
            return CurrentUser(id=DEMO_USER_ID, phone="+2348000000000")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    if not settings.supabase_jwt_secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="SUPABASE_JWT_SECRET is not configured",
        )
    try:
        claims = jwt.decode(
            credentials.credentials,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
        )
        return CurrentUser(
            id=UUID(claims["sub"]),
            phone=claims.get("phone", ""),
        )
    except (JWTError, KeyError, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
        ) from error
