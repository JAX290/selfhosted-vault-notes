#!/usr/bin/env sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
nas_dir="$root_dir/nas"
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
backup_root="${BACKUP_ROOT:-$root_dir/backups}"
target="$backup_root/$timestamp"

mkdir -p "$target"
cd "$nas_dir"

if [ ! -f .env ]; then
  printf 'Missing %s/.env\n' "$nas_dir" >&2
  exit 1
fi

printf 'Dumping Joplin PostgreSQL database...\n'
docker compose exec -T postgres sh -c \
  'pg_dump --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --format=custom' \
  > "$target/joplin-postgres.dump"

printf 'Pausing Vaultwarden for a consistent filesystem copy...\n'
docker compose stop vaultwarden
trap 'docker compose start vaultwarden >/dev/null 2>&1 || true' EXIT INT TERM
tar -czf "$target/vaultwarden-data.tar.gz" -C "$nas_dir/data" vaultwarden
docker compose start vaultwarden
trap - EXIT INT TERM

cp compose.yaml Caddyfile .env.example "$target/"
printf 'Backup created at %s\n' "$target"
printf 'Copy it to encrypted off-site storage and test restoration regularly.\n'
