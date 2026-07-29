"""Apply ordered SQL migrations before the API starts."""

from __future__ import annotations

import hashlib
import os
import time
from pathlib import Path

import psycopg
from psycopg import ClientCursor

MIGRATIONS_DIR = Path(__file__).resolve().parent.parent / "migrations"
MIGRATION_LOCK_ID = 1_348_293_451
MAX_ATTEMPTS = 30
RETRY_SECONDS = 2


def psycopg_dsn(database_url: str) -> str:
    """Convert SQLAlchemy's psycopg URL into a libpq-compatible DSN."""
    return database_url.replace("postgresql+psycopg://", "postgresql://", 1)


def apply_migrations(database_url: str) -> None:
    migration_files = sorted(MIGRATIONS_DIR.glob("*.sql"))
    if not migration_files:
        raise RuntimeError(f"No SQL migrations found in {MIGRATIONS_DIR}")

    # ClientCursor uses PostgreSQL's simple-query protocol, which safely accepts
    # migration files containing more than one SQL statement.
    with psycopg.connect(
        psycopg_dsn(database_url),
        cursor_factory=ClientCursor,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT pg_advisory_lock(%s)", (MIGRATION_LOCK_ID,))
            try:
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS _dey_alert_schema_migrations (
                      filename TEXT PRIMARY KEY,
                      checksum TEXT NOT NULL,
                      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                connection.commit()

                for migration_file in migration_files:
                    sql = migration_file.read_text(encoding="utf-8")
                    checksum = hashlib.sha256(sql.encode("utf-8")).hexdigest()
                    cursor.execute(
                        """
                        SELECT checksum
                        FROM _dey_alert_schema_migrations
                        WHERE filename = %s
                        """,
                        (migration_file.name,),
                    )
                    row = cursor.fetchone()
                    if row:
                        if row[0] != checksum:
                            raise RuntimeError(
                                f"Applied migration changed: {migration_file.name}"
                            )
                        continue

                    print(f"Applying migration {migration_file.name}", flush=True)
                    cursor.execute(sql)
                    cursor.execute(
                        """
                        INSERT INTO _dey_alert_schema_migrations (filename, checksum)
                        VALUES (%s, %s)
                        """,
                        (migration_file.name, checksum),
                    )
                    connection.commit()
            finally:
                connection.rollback()
                cursor.execute("SELECT pg_advisory_unlock(%s)", (MIGRATION_LOCK_ID,))
                connection.commit()


def main() -> None:
    database_url = os.environ.get("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is required")

    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            apply_migrations(database_url)
            print("Database migrations are up to date", flush=True)
            return
        except psycopg.OperationalError as error:
            if attempt == MAX_ATTEMPTS:
                raise
            print(
                f"Database unavailable ({attempt}/{MAX_ATTEMPTS}): {error}. "
                f"Retrying in {RETRY_SECONDS}s...",
                flush=True,
            )
            time.sleep(RETRY_SECONDS)


if __name__ == "__main__":
    main()
