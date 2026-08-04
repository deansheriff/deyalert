from __future__ import annotations

from pathlib import Path
from typing import Annotated
from urllib.parse import quote
from uuid import uuid4

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile

from app.core.config import get_settings
from app.core.security import CurrentUser, get_current_user
from app.services.audit_service import record_audit

router = APIRouter(prefix="/media", tags=["media"])
User = Annotated[CurrentUser, Depends(get_current_user)]

_ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".mp4", ".mov"}
_ALLOWED_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "video/mp4",
    "video/quicktime",
    "application/octet-stream",
}


def _matches_file_signature(extension: str, content: bytes) -> bool:
    if extension in {".jpg", ".jpeg"}:
        return content.startswith(b"\xff\xd8\xff")
    if extension == ".png":
        return content.startswith(b"\x89PNG\r\n\x1a\n")
    if extension == ".webp":
        return content.startswith(b"RIFF") and content[8:12] == b"WEBP"
    if extension in {".mp4", ".mov"}:
        return len(content) >= 12 and content[4:8] == b"ftyp"
    return False


@router.post("/upload")
async def upload_incident_media(
    file: UploadFile,
    user: User,
    request: Request,
) -> dict[str, str]:
    settings = get_settings()
    extension = Path(file.filename or "").suffix.lower()
    if extension not in _ALLOWED_EXTENSIONS or file.content_type not in _ALLOWED_TYPES:
        raise HTTPException(status_code=415, detail="Unsupported media type")
    content = await file.read(settings.max_media_bytes + 1)
    if not content or len(content) > settings.max_media_bytes:
        raise HTTPException(status_code=413, detail="Media file is too large")
    if not _matches_file_signature(extension, content):
        raise HTTPException(status_code=415, detail="File content does not match its type")
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise HTTPException(status_code=503, detail="Media storage is not configured")

    object_name = f"{user.id}/{uuid4()}{extension}"
    storage_url = (
        f"{settings.supabase_url.rstrip('/')}/storage/v1/object/"
        f"{settings.media_bucket}/{quote(object_name)}"
    )
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            storage_url,
            content=content,
            headers={
                "Authorization": f"Bearer {settings.supabase_service_role_key}",
                "apikey": settings.supabase_service_role_key,
                "Content-Type": file.content_type or "application/octet-stream",
                "x-upsert": "false",
            },
        )
    if response.status_code >= 300:
        raise HTTPException(status_code=502, detail="Media storage rejected the upload")
    public_url = (
        f"{settings.supabase_url.rstrip('/')}/storage/v1/object/public/"
        f"{settings.media_bucket}/{quote(object_name)}"
    )
    record_audit(
        actor_id=user.id,
        action="media.upload",
        entity_type="media",
        metadata={"object": object_name, "bytes": len(content)},
        ip_address=request.client.host if request.client else None,
    )
    return {"url": public_url}
