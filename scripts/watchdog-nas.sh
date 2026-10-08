#!/bin/sh
set -u

base=/volume1/docker/vault-notes
compose_dir="$base/nas"
state_dir="$base/secrets/watchdog"
state_file="$state_dir/nas-failures"
lock_file="$state_dir/nas.lock"
mkdir -p "$state_dir"
exec 9>"$lock_file"
flock -n 9 || exit 0

log() { logger -t vault-notes-watchdog -- "$*"; printf '%s\n' "$*"; }

check_local() {
  docker inspect -f '{{.State.Running}}' vault-notes-vaultwarden 2>/dev/null | grep -qx true || return 1
  curl -fsS --connect-timeout 3 --max-time 10 http://127.0.0.1:8080/alive >/dev/null || return 1
  docker exec vault-notes-caddy wget -qO- http://vaultwarden/alive >/dev/null 2>&1 || return 1
  docker exec vault-notes-caddy wget -qO- http://joplin:22300/api/ping >/dev/null 2>&1 || return 1
  docker exec tailscale tailscale status >/dev/null 2>&1 || return 1
}

if check_local; then
  printf '0\n' > "$state_file"
  exit 0
fi

failures=0
test -r "$state_file" && read -r failures < "$state_file" || true
case "$failures" in *[!0-9]*|'') failures=0;; esac
failures=$((failures + 1))
printf '%s\n' "$failures" > "$state_file"
log "NAS health check failed (${failures}/2)"
[ "$failures" -ge 2 ] || exit 0

if docker inspect vaultwarden >/dev/null 2>&1; then
  docker update --restart=no vaultwarden >/dev/null 2>&1 || true
  docker stop vaultwarden >/dev/null 2>&1 || true
fi

cd "$compose_dir" || exit 1
docker compose -f compose.yaml -f compose.compat.yaml up -d --no-build --pull never postgres joplin vaultwarden caddy
docker start tailscale >/dev/null 2>&1 || true
sleep 12

if check_local; then
  printf '0\n' > "$state_file"
  log "NAS services recovered; legacy Vaultwarden remains disabled"
  exit 0
fi

log "automatic NAS recovery failed; manual inspection required"
exit 1
