#!/bin/sh
set -eu

: "${BACKUP_FILE:?BACKUP_FILE is required}"
RESTORE_DIR="${RESTORE_DIR:-$(mktemp -d)}"
cleanup() {
  rm -rf "$RESTORE_DIR"
}
trap cleanup EXIT

mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"
test -n "$(find "$RESTORE_DIR" -type f -print -quit)"

echo "Storage restore verification completed successfully"
