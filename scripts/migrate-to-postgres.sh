#!/usr/bin/env bash
# Migrate a Compose-managed MeshMonitor installation from SQLite to PostgreSQL.
#
# The original compose file is never edited. This script creates a reusable
# PostgreSQL override, migrates over the Compose network, starts MeshMonitor
# with DATABASE_URL set, and restores SQLite automatically after an error.

set -euo pipefail

COMPOSE_FILE="${1:-docker-compose.yml}"
MESHMONITOR_SERVICE="${MESHMONITOR_SERVICE:-meshmonitor}"
POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-meshmonitor}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -hex 16)}"
POSTGRES_DB="${POSTGRES_DB:-meshmonitor}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:16-alpine}"
OVERRIDE_FILE="${POSTGRES_OVERRIDE_FILE:-docker-compose.postgres.yml}"
BACKUP_DIR="${MIGRATION_BACKUP_DIR:-./migration-backup-$(date +%Y%m%d-%H%M%S)}"

info() { printf '[INFO] %s\n' "$1"; }
success() { printf '[SUCCESS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1" >&2; }
fail() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

for command_name in docker openssl; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required"
done
docker compose version >/dev/null 2>&1 || fail 'docker compose is required'
[ -f "$COMPOSE_FILE" ] || fail "Compose file not found: $COMPOSE_FILE"
docker compose -f "$COMPOSE_FILE" config --services | grep -Fxq "$MESHMONITOR_SERVICE" \
  || fail "Service '$MESHMONITOR_SERVICE' was not found in $COMPOSE_FILE"

mkdir -p "$BACKUP_DIR"
BACKUP_DIR_ABS="$(cd "$BACKUP_DIR" && pwd)"
cp "$COMPOSE_FILE" "$BACKUP_DIR_ABS/$(basename "$COMPOSE_FILE").backup"

CONTAINER_ID="$(docker compose -f "$COMPOSE_FILE" ps -q "$MESHMONITOR_SERVICE")"
[ -n "$CONTAINER_ID" ] || fail "Service '$MESHMONITOR_SERVICE' is not running"

rollback() {
  warn 'Restoring the original SQLite deployment...'
  docker compose -f "$COMPOSE_FILE" up -d "$MESHMONITOR_SERVICE" || true
}

info 'Stopping MeshMonitor for a consistent SQLite snapshot...'
docker compose -f "$COMPOSE_FILE" stop "$MESHMONITOR_SERVICE"
trap rollback ERR

docker cp "$CONTAINER_ID:/data/meshmonitor.db" "$BACKUP_DIR_ABS/meshmonitor.db"
if [ ! -s "$BACKUP_DIR_ABS/meshmonitor.db" ]; then
  warn 'The SQLite backup is missing or empty'
  rollback
  exit 1
fi
success "SQLite database backed up to $BACKUP_DIR_ABS/meshmonitor.db"

cat > "$OVERRIDE_FILE" <<EOF
services:
  $POSTGRES_SERVICE:
    image: $POSTGRES_IMAGE
    restart: unless-stopped
    environment:
      POSTGRES_DB: $POSTGRES_DB
      POSTGRES_USER: $POSTGRES_USER
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
    volumes:
      - meshmonitor-postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB"]
      interval: 5s
      timeout: 5s
      retries: 20

  $MESHMONITOR_SERVICE:
    environment:
      DATABASE_URL: postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_SERVICE:5432/$POSTGRES_DB
    depends_on:
      $POSTGRES_SERVICE:
        condition: service_healthy

volumes:
  meshmonitor-postgres-data:
EOF

compose=(docker compose -f "$COMPOSE_FILE" -f "$OVERRIDE_FILE")
info 'Starting PostgreSQL...'
"${compose[@]}" up -d --wait "$POSTGRES_SERVICE"

TARGET_URL="postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_SERVICE:5432/$POSTGRES_DB"
info 'Running migration with the MeshMonitor image from this Compose project...'
"${compose[@]}" run --rm --no-deps \
  -v "$BACKUP_DIR_ABS/meshmonitor.db:/migration-source.db:ro" \
  "$MESHMONITOR_SERVICE" npm run migrate-db -- \
  --from sqlite:/migration-source.db \
  --to "$TARGET_URL"

info 'Starting MeshMonitor with PostgreSQL...'
"${compose[@]}" up -d --wait "$MESHMONITOR_SERVICE"
trap - ERR

success 'Migration complete and MeshMonitor restarted on PostgreSQL.'
printf '\nKeep using both Compose files for future operations:\n'
printf '  docker compose -f %s -f %s up -d\n' "$COMPOSE_FILE" "$OVERRIDE_FILE"
printf '\nBackup: %s\n' "$BACKUP_DIR_ABS"
