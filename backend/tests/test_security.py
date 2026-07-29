from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec

from app.core.config import get_settings
from app.core import security


@pytest.fixture(autouse=True)
def clear_settings_cache() -> None:
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def token_claims() -> dict[str, object]:
    return {
        "sub": str(uuid4()),
        "aud": "authenticated",
        "phone": "+2348012345678",
        "exp": datetime.now(timezone.utc) + timedelta(minutes=5),
    }


def test_decodes_legacy_hs256_token(monkeypatch: pytest.MonkeyPatch) -> None:
    secret = "a-production-secret-with-enough-entropy"
    monkeypatch.setenv("SUPABASE_JWT_SECRET", secret)
    claims = token_claims()
    token = jwt.encode(claims, secret, algorithm="HS256")

    decoded = security.decode_supabase_token(token)

    assert decoded["sub"] == claims["sub"]


def test_decodes_asymmetric_token_from_jwks(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key = private_key.public_key()
    claims = token_claims()
    token = jwt.encode(
        claims,
        private_key,
        algorithm="ES256",
        headers={"kid": "dey-alert-test"},
    )
    monkeypatch.setenv("SUPABASE_URL", "https://supabase.example.com")
    monkeypatch.setattr(
        security,
        "get_jwk_client",
        lambda _: SimpleNamespace(
            get_signing_key_from_jwt=lambda __: SimpleNamespace(key=public_key)
        ),
    )

    decoded = security.decode_supabase_token(token)

    assert decoded["sub"] == claims["sub"]
