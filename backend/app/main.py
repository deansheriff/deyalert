from fastapi import FastAPI

from app.api.incidents import router as incidents_router

app = FastAPI(title="Dey Alert API", version="0.1.0")
app.include_router(incidents_router)


@app.get("/health", tags=["system"])
def health() -> dict[str, str]:
    return {"status": "ok", "service": "dey-alert-api"}
