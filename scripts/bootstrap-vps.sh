#!/bin/sh
# Only for a clean Ubuntu 24.04 VPS, without existing port 80/443 services.
set -eu
test "$(id -u)" -eq 0 || { echo 'Run as root'; exit 1; }
. /etc/os-release
test "$ID" = ubuntu && test "$VERSION_ID" = 24.04 || { echo 'Ubuntu 24.04 required'; exit 1; }
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test -f "$root_dir/vps/host.env" || { echo 'Copy vps/host.env.example to vps/host.env and fill it first'; exit 1; }
edge_ip=$(ip -4 route get 1.1.1.1 | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')
if ss -H -lnt '( sport = :80 or sport = :443 )' | awk -v ip="$edge_ip" '
  $4 ~ /^(0\.0\.0\.0|\*|\[::\]):(80|443)$/ || $4 == ip ":80" || $4 == ip ":443" { found=1 }
  END { exit !found }
'; then
  echo 'Existing 80/443 listener found; use reviewed coexist configuration instead'
  exit 1
fi
apt-get update
new_haproxy=true
if dpkg-query -W -f='${Status}' haproxy 2>/dev/null | grep -q '^install ok installed$'; then
  new_haproxy=false
fi
DEBIAN_FRONTEND=noninteractive apt-get install -y haproxy curl ca-certificates
if [ "$new_haproxy" = true ]; then
  # The package may start its sample listener. This deployment uses its own unit.
  systemctl disable --now haproxy.service
fi
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
  echo 'Run tailscale up, authorize it in your existing tailnet, then rerun this script'
  echo 'Advertise tag:vps-gateway only after configuring its tag owner and grants'
  exit 1
fi
set -a
. /opt/vault-notes/edge.env
set +a
haproxy -c -f /opt/vault-notes/haproxy.cfg
systemctl enable --now vault-notes-edge
echo 'Gateway started; validate HTTPS before changing DNS'
