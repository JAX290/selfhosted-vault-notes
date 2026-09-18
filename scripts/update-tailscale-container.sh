#!/bin/sh
# Run as a user with Docker access. Configuration and backups contain private data.
set -eu
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
: "${1:?usage: update-tailscale-container.sh /path/to/update.env [--check]}"
. "$1"
: "${COMPOSE_DIR:?}" "${BACKUP_DIR:?}" "${VAULT_URL:?}" "${NOTES_URL:?}"
IMAGE=${IMAGE:-tailscale/tailscale:stable}
CONTAINER=${CONTAINER:-tailscale}
SERVICE=${SERVICE:-tailscale}
umask 077
mkdir -p "$BACKUP_DIR"
exec 9>"$BACKUP_DIR/update.lock"
flock -n 9 || exit 0
cd "$COMPOSE_DIR"
base="$COMPOSE_DIR/docker-compose.yaml"
override="$BACKUP_DIR/update.override.yaml"
printf 'services:\n  %s:\n    image: %s\n' "$SERVICE" "$IMAGE" > "$override"
compose() { docker compose -f "$base" -f "$override" "$@"; }
compose config --quiet
old_image=$(docker inspect "$CONTAINER" --format '{{.Image}}')
state_dir=$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Destination "/var/lib/tailscale"}}{{.Source}}{{end}}{{end}}')
test -n "$state_dir"
test -d "$state_dir"
docker exec "$CONTAINER" tailscale status --json | python3 -c 'import json,sys; assert json.load(sys.stdin)["BackendState"] == "Running"'
if [ "${2:-}" = --check ]; then
  printf '%s Configuration valid; node running; persistent state found.\n' "$(date -Is)"
  exit 0
fi
printf '%s Checking stable image...\n' "$(date -Is)"
timeout 900 docker pull "$IMAGE"
new_image=$(docker image inspect "$IMAGE" --format '{{.Id}}')
if [ "$new_image" = "$old_image" ]; then
  printf '%s Already current; no restart required.\n' "$(date -Is)"
  exit 0
fi
snapshot="$BACKUP_DIR/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir "$snapshot"
docker exec "$CONTAINER" tailscale ip -4 > "$snapshot/ip.txt"
docker exec "$CONTAINER" tailscale serve status --json > "$snapshot/serve.json"
cp -p "$base" "$snapshot/docker-compose.yaml"
printf '%s\n' "$old_image" > "$snapshot/old-image.txt"
rollback() {
  trap - EXIT INT TERM
  printf '%s Update failed; restoring old image.\n' "$(date -Is)" >&2
  docker tag "$old_image" "$IMAGE"
  compose up -d --no-deps --pull never "$SERVICE" || true
  printf 'State backup retained at %s; inspect the log before retrying.\n' "$snapshot" >&2
  exit 1
}
trap rollback EXIT INT TERM
docker stop "$CONTAINER" >/dev/null
docker run --rm --network none --entrypoint /bin/sh -v "$state_dir:/source:ro" "$old_image" -c 'tar -czf - -C /source .' > "$snapshot/state.tar.gz"
compose up -d --no-deps --pull never "$SERVICE"
ready=false
for attempt in $(seq 1 30); do
  if docker exec "$CONTAINER" tailscale status --json 2>/dev/null | python3 -c 'import json,sys; assert json.load(sys.stdin)["BackendState"] == "Running"' 2>/dev/null; then ready=true; break; fi
  sleep 2
done
test "$ready" = true
docker exec "$CONTAINER" tailscale ip -4 > "$snapshot/ip-after.txt"
cmp "$snapshot/ip.txt" "$snapshot/ip-after.txt"
docker exec "$CONTAINER" tailscale serve status --json > "$snapshot/serve-after.json"
python3 - "$snapshot/serve.json" "$snapshot/serve-after.json" <<'PY'
import json, sys
with open(sys.argv[1]) as a, open(sys.argv[2]) as b:
    assert json.load(a) == json.load(b), 'Serve configuration changed'
PY
curl --fail --silent --show-error --retry 3 --retry-delay 5 --max-time 20 "$VAULT_URL/alive" >/dev/null
curl --fail --silent --show-error --retry 3 --retry-delay 5 --max-time 20 "$NOTES_URL/api/ping" >/dev/null
trap - EXIT INT TERM
printf '%s Update succeeded; node identity, forwarding and HTTPS checks passed.\n' "$(date -Is)"
docker exec "$CONTAINER" tailscale version
