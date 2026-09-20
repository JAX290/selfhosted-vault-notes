#!/bin/sh
# Add the NAS TLS gateway to a reviewed VPS where Nginx already owns its public-IP port 443.
set -eu
test "$(id -u)" -eq 0 || { echo 'Run as root'; exit 1; }
. /etc/os-release
test "$ID" = ubuntu && test "$VERSION_ID" = 24.04 || { echo 'Ubuntu 24.04 required'; exit 1; }
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
private_env="$root_dir/vps/coexist.env"
test -f "$private_env" || { echo 'Copy vps/coexist.env.example to vps/coexist.env and fill it first'; exit 1; }
set -a
. "$private_env"
set +a
: "${EDGE_BIND_ADDRESS:?}" "${VAULT_DOMAIN:?}" "${NOTES_DOMAIN:?}"
: "${NAS_TAILSCALE_IP:?}" "${NAS_TLS_PORT:?}" "${EXISTING_TLS_ADDRESS:?}"
: "${NGINX_SITE:?}" "${EXISTING_TEST_DOMAIN:?}" "${EXISTING_EXPECTED_STATUS:?}"
command -v haproxy >/dev/null
command -v nginx >/dev/null
command -v tailscale >/dev/null
command -v python3 >/dev/null
test -f "$NGINX_SITE"
systemctl is-active --quiet nginx
systemctl is-active --quiet haproxy
tailscale ip -4 >/dev/null
curl --fail --silent --show-error --max-time 20 "https://${VAULT_DOMAIN}:8443/alive" \
  --resolve "${VAULT_DOMAIN}:8443:${NAS_TAILSCALE_IP}" >/dev/null
curl --fail --silent --show-error --max-time 20 "https://${NOTES_DOMAIN}:8443/api/ping" \
  --resolve "${NOTES_DOMAIN}:8443:${NAS_TAILSCALE_IP}" -H "Host: ${NOTES_DOMAIN}" >/dev/null
install -d -m 755 /opt/vault-notes
install -m 644 "$root_dir/vps/haproxy-coexist.cfg" /opt/vault-notes/haproxy.cfg
install -m 644 "$root_dir/vps/vault-notes-edge.service" /etc/systemd/system/vault-notes-edge.service
umask 077
cat > /opt/vault-notes/edge.env <<EOF
EDGE_BIND_ADDRESS=$EDGE_BIND_ADDRESS
VAULT_DOMAIN=$VAULT_DOMAIN
NOTES_DOMAIN=$NOTES_DOMAIN
NAS_TAILSCALE_IP=$NAS_TAILSCALE_IP
NAS_TLS_PORT=$NAS_TLS_PORT
EXISTING_TLS_ADDRESS=$EXISTING_TLS_ADDRESS
EOF
haproxy -c -f /opt/vault-notes/haproxy.cfg
if systemctl is-active --quiet vault-notes-edge; then
  echo 'Coexist gateway is already active; configuration validated.'
  exit 0
fi
needle="listen ${EDGE_BIND_ADDRESS}:443 ssl;"
grep -Fq "$needle" "$NGINX_SITE" || {
  echo "Expected Nginx line not found: $needle" >&2
  exit 1
}
backup="${NGINX_SITE}.before-vault-notes-$(date -u +%Y%m%dT%H%M%SZ)"
cp -a "$NGINX_SITE" "$backup"
rollback() {
  trap - EXIT INT TERM
  systemctl stop vault-notes-edge.service >/dev/null 2>&1 || true
  cp -a "$backup" "$NGINX_SITE"
  nginx -t && systemctl reload nginx
  echo 'Activation failed; original Nginx configuration restored.' >&2
  exit 1
}
trap rollback EXIT INT TERM
python3 - "$NGINX_SITE" "$needle" <<'PY'
from pathlib import Path
import sys
p, needle = Path(sys.argv[1]), sys.argv[2]
lines = p.read_text().splitlines(keepends=True)
kept = [line for line in lines if line.strip() != needle]
if len(kept) != len(lines) - 1:
    raise SystemExit('Expected exactly one matching Nginx listen line')
p.write_text(''.join(kept))
PY
nginx -t
systemctl reload nginx
systemctl daemon-reload
systemctl enable --now vault-notes-edge.service
sleep 2
systemctl is-active --quiet nginx
systemctl is-active --quiet haproxy
systemctl is-active --quiet vault-notes-edge
curl --fail --silent --show-error --resolve "${VAULT_DOMAIN}:443:${EDGE_BIND_ADDRESS}" "https://${VAULT_DOMAIN}/alive" >/dev/null
curl --fail --silent --show-error --resolve "${NOTES_DOMAIN}:443:${EDGE_BIND_ADDRESS}" "https://${NOTES_DOMAIN}/api/ping" >/dev/null
status=$(curl --silent --show-error --resolve "${EXISTING_TEST_DOMAIN}:443:${EDGE_BIND_ADDRESS}" \
  "https://${EXISTING_TEST_DOMAIN}/" -o /dev/null -w '%{http_code}')
test "$status" = "$EXISTING_EXPECTED_STATUS"
trap - EXIT INT TERM
echo 'Coexist gateway active; existing HAProxy and website checks passed.'
