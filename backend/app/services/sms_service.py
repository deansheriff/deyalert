from __future__ import annotations

import httpx

from app.core.config import get_settings


def sms_is_configured() -> bool:
    settings = get_settings()
    if settings.sms_provider == "termii":
        return bool(settings.sms_api_key and settings.sms_sender_id)
    if settings.sms_provider == "twilio":
        return bool(
            settings.twilio_account_sid
            and settings.twilio_auth_token
            and settings.twilio_from_number
        )
    return False


def send_sms(phone: str, message: str) -> bool:
    settings = get_settings()
    try:
        if settings.sms_provider == "termii":
            response = httpx.post(
                "https://v3.api.termii.com/api/sms/send",
                json={
                    "to": phone,
                    "from": settings.sms_sender_id,
                    "sms": message,
                    "type": "plain",
                    "channel": "generic",
                    "api_key": settings.sms_api_key,
                },
                timeout=10,
            )
        elif settings.sms_provider == "twilio":
            response = httpx.post(
                "https://api.twilio.com/2010-04-01/Accounts/"
                f"{settings.twilio_account_sid}/Messages.json",
                data={
                    "To": phone,
                    "From": settings.twilio_from_number,
                    "Body": message,
                },
                auth=(settings.twilio_account_sid, settings.twilio_auth_token),
                timeout=10,
            )
        else:
            return False
        response.raise_for_status()
        return True
    except httpx.HTTPError:
        return False
