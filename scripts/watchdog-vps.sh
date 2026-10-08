#!/bin/sh
set -u

PATH=/usr/sbin:/usr/bin:/sbin:/bin
state_dir=/var/lib/vault-notes-watchdog
state_file="$state_dir/failures"
lock_file=/run/vault-notes-watchdog.lock
env_file=/opt/vault-notes/edge.env

mkdir -p "$state_dir"
exec 9>"$lock_file"
flock -n 9 || exit 0

log() { logger -t vault-notes-watchdog -- "$*"; printf '%s\n' "$*"; }
test -r "$env_file" || { log "edge environment is missing"; exit 1; }
set -a
. "$env_file"
set +a
: "${NAS_TAILSCALE_IP:?}" "${NAS_TLS_PORT:=8443}"

check_backend() {
  tailscale ip -4 >/dev/null 2>&1 || return 1
  if [ -n "${VAULT_DOMAIN:-}" ]; then
    curl -fsS --connect-timeout 5 --max-time 15 \
      --resolve "${VAULT_DOMAIN}:${NAS_TLS_PORT}:${NAS_TAILSCALE_IP}" \
      "https://${VAULT_DOMAIN}:${NAS_TLS_PORT}/alive" >/dev/null || return 1
  else
    timeout 10 bash -c "exec 3<>/dev/tcp/${NAS_TAILSCALE_IP}/${NAS_TLS_PORT}" 2>/dev/null || return 1
  fi
  if [ -n "${NOTES_DOMAIN:-}" ]; then
    curl -fsS --connect-timeout 5 --max-time 15 \
      --resolve "${NOTES_DOMAIN}:${NAS_TLS_PORT}:${NAS_TAILSCALE_IP}" \
      "https://${NOTES_DOMAIN}:${NAS_TLS_PORT}/api/ping" >/dev/null || return 1
  fi
}

check_edge() {
  systemctl is-active --quiet vault-notes-edge.service || return 1
  [ -n "${EDGE_BIND_ADDRESS:-}" ] || return 0
  [ -n "${VAULT_DOMAIN:-}" ] || return 0
  curl -fsS --connect-timeout 5 --max-time 15 \
    --resolve "${VAULT_DOMAIN}:443:${EDGE_BIND_ADDRESS}" \
    "https://${VAULT_DOMAIN}/alive" >/dev/null
}

if check_backend && check_edge; then
  printf '0\n' > "$state_file"
  exit 0
fi

failures=0
test -r "$state_file" && read -r failures < "$state_file" || true
case "$failures" in *[!0-9]*|'') failures=0;; esac
failures=$((failures + 1))
printf '%s\n' "$failures" > "$state_file"
log "health check failed (${failures}/2)"
[ "$failures" -ge 2 ] || exit 0

if ! check_backend; then
  log "restarting tailscaled after repeated NAS path failure"
  systemctl restart tailscaled.service
  sleep 8
fi

if check_backend && ! check_edge; then
  log "restarting vault-notes-edge; mining HAProxy is untouched"
  systemctl restart vault-notes-edge.service
  sleep 3
fi

if check_backend && check_edge; then
  printf '0\n' > "$state_file"
  log "service recovered"
  exit 0
fi

log "automatic recovery did not restore the path; manual inspection required"
exit 1
