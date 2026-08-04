#!/bin/sh
set -eu

: "${STORAGE_DIR:?STORAGE_DIR is required}"
BACKUP_DIR="${BACKUP_DIR:-/backups/dey-alert}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$BACKUP_DIR"
tar -C "$STORAGE_DIR" -czf "$BACKUP_DIR/dey-alert-storage-$STAMP.tar.gz" .
find "$BACKUP_DIR" -type f -name 'dey-alert-storage-*.tar.gz' \
  -mtime "+$RETENTION_DAYS" -delete

echo "Storage backup created: $BACKUP_DIR/dey-alert-storage-$STAMP.tar.gz"
