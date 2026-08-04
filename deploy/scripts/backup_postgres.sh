#!/bin/sh
set -eu

: "${DATABASE_URL:?DATABASE_URL is required}"
BACKUP_DIR="${BACKUP_DIR:-/backups/dey-alert}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$BACKUP_DIR"
pg_dump --format=custom --no-owner --no-acl "$DATABASE_URL" \
  > "$BACKUP_DIR/dey-alert-$STAMP.dump"
find "$BACKUP_DIR" -type f -name 'dey-alert-*.dump' \
  -mtime "+$RETENTION_DAYS" -delete

echo "Backup created: $BACKUP_DIR/dey-alert-$STAMP.dump"
