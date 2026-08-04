#!/bin/sh
set -eu

: "${RESTORE_DATABASE_URL:?RESTORE_DATABASE_URL is required}"
: "${BACKUP_FILE:?BACKUP_FILE is required}"

pg_restore --clean --if-exists --no-owner --no-acl \
  --dbname "$RESTORE_DATABASE_URL" "$BACKUP_FILE"

psql "$RESTORE_DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
SELECT COUNT(*) AS migrations FROM _dey_alert_schema_migrations;
SELECT COUNT(*) AS users FROM users;
SELECT COUNT(*) AS incidents FROM incidents;
SELECT PostGIS_Version();
SQL

echo "Restore verification completed successfully"
