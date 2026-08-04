from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Dey Alert API"
    environment: str = "development"
    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/dey_alert"
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""
    supabase_jwt_secret: str = ""
    supabase_jwks_url: str = ""
    cors_origins: str = ""
    allow_unauthenticated_dev: bool = True
    use_in_memory_store: bool = False
    flag_hide_threshold: int = 5
    corroboration_threshold: int = 3
    corroboration_radius_km: float = 2.0
    news_feeds_json: str = "[]"
    news_admin_emails: str = ""
    news_auto_publish: bool = False
    news_advisory_ttl_hours: int = 72
    news_cluster_radius_km: float = 25.0
    rate_limit_per_minute: int = 120
    sensitive_rate_limit_per_minute: int = 30
    media_rate_limit_per_minute: int = 10
    sos_rate_limit_per_hour: int = 3
    trust_proxy_headers: bool = False
    ntfy_base_url: str = ""
    ntfy_topic: str = ""
    ntfy_access_token: str = ""
    media_bucket: str = "incident-media"
    max_media_bytes: int = 10_000_000
    sms_provider: str = "disabled"
    sms_api_key: str = ""
    sms_sender_id: str = "DeyAlert"
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""
    metrics_token: str = ""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
