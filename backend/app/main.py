from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth import router as auth_router
from app.api.admin import router as admin_router
from app.api.incidents import router as incidents_router
from app.api.news import router as news_router
from app.api.media import router as media_router
from app.api.sos import router as sos_router
from app.api.notifications import router as notifications_router
from app.api.areas import router as areas_router
from app.core.config import get_settings
from app.core.rate_limit import RateLimitMiddleware
from app.core.metrics import MetricsMiddleware, metrics_response
from app.core.database import get_session_factory
from sqlalchemy import text

app = FastAPI(title="Dey Alert API", version="0.1.0")
app.add_middleware(MetricsMiddleware)
app.add_middleware(RateLimitMiddleware)

cors_origins = [
    origin.strip()
    for origin in get_settings().cors_origins.split(",")
    if origin.strip()
]
if cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials="*" not in cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(incidents_router)
app.include_router(news_router)
app.include_router(media_router)
app.include_router(sos_router)
app.include_router(notifications_router)
app.include_router(areas_router)


@app.get("/health", tags=["system"])
def health() -> dict[str, str]:
    return {"status": "ok", "service": "dey-alert-api"}


@app.get("/ready", tags=["system"])
def ready() -> dict[str, str]:
    try:
        with get_session_factory()() as session:
            session.execute(text("SELECT 1"))
    except Exception as error:
        raise HTTPException(status_code=503, detail="Database unavailable") from error
    return {"status": "ready", "service": "dey-alert-api"}


@app.get("/metrics", include_in_schema=False)
def metrics(authorization: str | None = Header(default=None)):
    token = get_settings().metrics_token
    if not token:
        raise HTTPException(status_code=404, detail="Metrics are disabled")
    if authorization != f"Bearer {token}":
        raise HTTPException(status_code=401, detail="Invalid metrics token")
    return metrics_response()
