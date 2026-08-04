from __future__ import annotations

from collections import defaultdict, deque
import re
from threading import Lock
from time import monotonic

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.core.config import get_settings


_PATH_ID = re.compile(
    r"/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}"
)


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Small single-instance limiter; Coolify should run one API worker."""

    def __init__(self, app: object) -> None:
        super().__init__(app)
        self._requests: dict[str, deque[float]] = defaultdict(deque)
        self._lock = Lock()

    async def dispatch(self, request: Request, call_next):  # type: ignore[no-untyped-def]
        if request.url.path == "/health":
            return await call_next(request)

        settings = get_settings()
        window_seconds = 60
        if request.method == "POST" and request.url.path == "/sos":
            limit = settings.sos_rate_limit_per_hour
            window_seconds = 3600
        elif request.method == "POST" and request.url.path == "/media/upload":
            limit = settings.media_rate_limit_per_minute
        else:
            limit = (
                settings.sensitive_rate_limit_per_minute
                if request.method not in {"GET", "HEAD", "OPTIONS"}
                else settings.rate_limit_per_minute
            )
        client = request.client.host if request.client else "unknown"
        if settings.trust_proxy_headers:
            client = (
                request.headers.get("cf-connecting-ip")
                or request.headers.get("x-forwarded-for", "").split(",")[0].strip()
                or client
            )
        normalized_path = _PATH_ID.sub("/{id}", request.url.path)
        key = f"{client}:{request.method}:{normalized_path}"
        now = monotonic()
        with self._lock:
            bucket = self._requests[key]
            while bucket and bucket[0] <= now - window_seconds:
                bucket.popleft()
            if len(bucket) >= limit:
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too many requests. Please try again shortly."},
                    headers={"Retry-After": str(window_seconds)},
                )
            bucket.append(now)
        return await call_next(request)
