#!/bin/sh
# Only for a clean Ubuntu 24.04 VPS, without existing port 80/443 services.
set -eu
test "$(id -u)" -eq 0 || { echo 'Run as root'; exit 1; }
. /etc/os-release
test "$ID" = ubuntu && test "$VERSION_ID" = 24.04 || { echo 'Ubuntu 24.04 required'; exit 1; }
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test -f "$root_dir/vps/host.env" || { echo 'Copy vps/host.env.example to vps/host.env and fill it first'; exit 1; }
if ss -H -lnt '( sport = :80 or sport = :443 )' | grep -q .; then
  echo 'Existing 80/443 listener found; use reviewed coexist configuration instead'
  exit 1
fi
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y haproxy curl ca-certificates
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale
fi
install -d -m 755 /opt/vault-notes
install -m 600 "$root_dir/vps/host.env" /opt/vault-notes/edge.env
install -m 644 "$root_dir/vps/haproxy-standalone.cfg" /opt/vault-notes/haproxy.cfg
install -m 644 "$root_dir/vps/vault-notes-edge.service" /etc/systemd/system/vault-notes-edge.service
systemctl daemon-reload
if ! tailscale ip -4 >/dev/null 2>&1; then
  echo 'Run tailscale up --advertise-tags=tag:vps-gateway, authorize it, then rerun this script'
  exit 1
fi
set -a
. /opt/vault-notes/edge.env
set +a
haproxy -c -f /opt/vault-notes/haproxy.cfg
systemctl enable --now vault-notes-edge
echo 'Gateway started; validate HTTPS before changing DNS'
