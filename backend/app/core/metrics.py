from __future__ import annotations

from time import perf_counter

from fastapi import Request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response


REQUESTS = Counter(
    "dey_alert_http_requests_total",
    "HTTP requests handled by the Dey Alert API.",
    ("method", "route", "status"),
)
LATENCY = Histogram(
    "dey_alert_http_request_duration_seconds",
    "Dey Alert API request duration.",
    ("method", "route"),
)


class MetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):  # type: ignore[no-untyped-def]
        started = perf_counter()
        status = 500
        try:
            response = await call_next(request)
            status = response.status_code
            return response
        finally:
            route = request.scope.get("route")
            path = getattr(route, "path", "unmatched")
            REQUESTS.labels(request.method, path, str(status)).inc()
            LATENCY.labels(request.method, path).observe(perf_counter() - started)


def metrics_response() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
