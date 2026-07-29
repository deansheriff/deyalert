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
    ntfy_topic: str = "dey-alert-dev"
    flag_hide_threshold: int = 5
    corroboration_threshold: int = 3
    corroboration_radius_km: float = 2.0

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
