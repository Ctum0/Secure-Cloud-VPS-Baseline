#!/usr/bin/env bash
#
# backup.sh — backup Docker named volumes to tar.gz archives.
# Retention: backups older than 7 days are deleted automatically.
#
# Usage:
#   ./backup.sh <volume-or-path> [volume-or-path ...]
#
# Accepts Docker named volumes (e.g. portainer_data) or host directories
# (e.g. config/homarr/appdata). Relative paths resolve from the current
# working directory.
#
# Examples:
#   ./backup.sh portainer_data
#   ./backup.sh portainer_data config/homarr/appdata
#
# Set BACKUP_DIR to override the destination (default: ./backups).

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS=7
DATE_STAMP="$(date +%Y%m%d_%H%M%S)"

backup_volume() {
  local volume="$1"
  local name="$(basename "${volume}")"
  local archive="${name}_${DATE_STAMP}.tar.gz"

  echo "[$(date -u +%FT%TZ)] Backing up volume: ${volume}"
  docker run --rm \
    -v "${volume}":/volume:ro \
    -v "${BACKUP_DIR}":/backup \
    alpine:latest \
    tar czf "/backup/${archive}" -C /volume .
  echo "[$(date -u +%FT%TZ)] Created: ${BACKUP_DIR}/${archive}"
}

main() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <volume-or-path> [volume-or-path ...]" >&2
    echo "Example: $0 portainer_data config/homarr/appdata" >&2
    exit 1
  fi

  mkdir -p "${BACKUP_DIR}"

  for volume in "$@"; do
    backup_volume "$volume"
  done

  echo "[$(date -u +%FT%TZ)] Removing backups older than ${RETENTION_DAYS} days"
  find "${BACKUP_DIR}" -name '*.tar.gz' -mtime "+${RETENTION_DAYS}" -delete
  echo "[$(date -u +%FT%TZ)] Backup run complete"
}

main "$@"
