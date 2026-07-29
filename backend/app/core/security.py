from dataclasses import dataclass
from functools import lru_cache
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient
from jwt.exceptions import PyJWTError

from app.core.config import get_settings

bearer = HTTPBearer(auto_error=False)
DEMO_USER_ID = UUID("00000000-0000-4000-8000-000000000001")


@dataclass(frozen=True)
class CurrentUser:
    id: UUID
    email: str | None


@lru_cache(maxsize=4)
def get_jwk_client(jwks_url: str) -> PyJWKClient:
    return PyJWKClient(jwks_url, cache_keys=True, lifespan=600, timeout=10)


def decode_supabase_token(token: str) -> dict:
    settings = get_settings()
    header = jwt.get_unverified_header(token)
    algorithm = header.get("alg", "")

    if algorithm == "HS256":
        if not settings.supabase_jwt_secret:
            raise RuntimeError(
                "SUPABASE_JWT_SECRET is required for legacy HS256 tokens"
            )
        key = settings.supabase_jwt_secret
        algorithms = ["HS256"]
    else:
        jwks_url = settings.supabase_jwks_url.strip()
        if not jwks_url and settings.supabase_url:
            jwks_url = (
                f"{settings.supabase_url.rstrip('/')}"
                "/auth/v1/.well-known/jwks.json"
            )
        if not jwks_url:
            raise RuntimeError(
                "SUPABASE_URL or SUPABASE_JWKS_URL is required for JWT verification"
            )
        key = get_jwk_client(jwks_url).get_signing_key_from_jwt(token).key
        algorithms = ["ES256", "RS256"]

    return jwt.decode(
        token,
        key,
        algorithms=algorithms,
        audience="authenticated",
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> CurrentUser:
    settings = get_settings()
    if credentials is None:
        if settings.allow_unauthenticated_dev:
            return CurrentUser(id=DEMO_USER_ID, email="demo@deyalert.local")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    try:
        claims = decode_supabase_token(credentials.credentials)
        return CurrentUser(
            id=UUID(claims["sub"]),
            email=claims.get("email"),
        )
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(error),
        ) from error
    except (PyJWTError, KeyError, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
        ) from error
