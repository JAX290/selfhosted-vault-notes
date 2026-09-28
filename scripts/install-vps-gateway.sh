#!/bin/sh
# Interactive entry point for a Tailscale-connected Ubuntu 24.04 VPS.
set -eu
test "$(id -u)" -eq 0 || { echo '请使用 root 运行'; exit 1; }
. /etc/os-release
test "$ID" = ubuntu && test "$VERSION_ID" = 24.04 || { echo '仅支持 Ubuntu 24.04'; exit 1; }
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
command -v tailscale >/dev/null || { echo '请先安装并认证 Tailscale'; exit 1; }
tailscale ip -4 >/dev/null 2>&1 || { echo '请先执行 tailscale up 完成认证'; exit 1; }
command -v curl >/dev/null || { apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates; }

prompt() {
  label=$1; default=${2:-}
  if [ -n "$default" ]; then printf '%s [%s]: ' "$label" "$default" >&2; else printf '%s: ' "$label" >&2; fi
  IFS= read -r answer
  printf '%s\n' "${answer:-$default}"
}
valid_ip() {
  python3 - "$1" <<'PY'
import ipaddress, sys
ipaddress.ip_address(sys.argv[1])
PY
}
valid_domain() { printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$'; }

if systemctl is-active --quiet vault-notes-edge.service 2>/dev/null; then
  echo '网关已经运行，无需重复安装。'
  systemctl status vault-notes-edge.service --no-pager
  exit 0
fi
edge_ip=$(ip -4 route get 1.1.1.1 | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')
valid_ip "$edge_ip"
NAS_TAILSCALE_IP=${NAS_TAILSCALE_IP:-$(prompt 'NAS 的 Tailscale IPv4')}
valid_ip "$NAS_TAILSCALE_IP" || { echo 'NAS Tailscale IP 无效' >&2; exit 1; }

public_listener=false
if ss -H -lnt '( sport = :80 or sport = :443 )' | awk -v ip="$edge_ip" '
  $4 ~ /^(0\.0\.0\.0|\*|\[::\]):(80|443)$/ || $4 == ip ":80" || $4 == ip ":443" { found=1 }
  END { exit !found }
'; then public_listener=true; fi

if [ "$public_listener" = false ]; then
  cat > "$root_dir/vps/host.env" <<EOF
EDGE_BIND_ADDRESS=0.0.0.0
NAS_TAILSCALE_IP=$NAS_TAILSCALE_IP
NAS_TLS_PORT=8443
EOF
  echo '检测为独立模式：公网 80/443 当前未被占用。'
  exec sh "$root_dir/scripts/bootstrap-vps.sh"
fi

echo '检测为共存模式：已有服务占用公网 80/443。'
command -v nginx >/dev/null || { echo '共存模式要求现有服务由 Nginx 提供'; exit 1; }
command -v haproxy >/dev/null || { echo '共存模式要求已安装 HAProxy'; exit 1; }
systemctl is-active --quiet nginx || { echo 'Nginx 未运行'; exit 1; }
systemctl is-active --quiet haproxy || { echo '系统 HAProxy 未运行'; exit 1; }
edge_pattern=$(printf '%s' "$edge_ip" | sed 's/\./\\./g')
matches=''
for enabled in /etc/nginx/sites-enabled/*; do
  [ -e "$enabled" ] || continue
  if grep -Eq "^[[:space:]]*listen[[:space:]]+${edge_pattern}:443[[:space:]]+ssl;" "$enabled"; then
    resolved=$(readlink -f "$enabled")
    case " $matches " in *" $resolved "*) ;; *) matches="$matches $resolved" ;; esac
  fi
done
set -- $matches
test "$#" -eq 1 || { echo '无法唯一确定监听公网网卡 443 的 Nginx 配置，请人工检查 /etc/nginx/sites-enabled。' >&2; exit 1; }
nginx_site=$1
detected_domain=$(awk '$1=="server_name" {gsub(/;/,"",$2); if ($2!="_") {print $2; exit}}' "$nginx_site")
VAULT_DOMAIN=${VAULT_DOMAIN:-$(prompt 'Vaultwarden 域名（不含 https://）')}
NOTES_DOMAIN=${NOTES_DOMAIN:-$(prompt 'Joplin 域名（不含 https://）')}
EXISTING_TEST_DOMAIN=${EXISTING_TEST_DOMAIN:-$(prompt '原 Nginx 网站域名' "$detected_domain")}
valid_domain "$VAULT_DOMAIN" && valid_domain "$NOTES_DOMAIN" && valid_domain "$EXISTING_TEST_DOMAIN" || { echo '域名格式无效' >&2; exit 1; }
existing_status=$(curl --silent --show-error --max-time 20 --resolve "${EXISTING_TEST_DOMAIN}:443:127.0.0.1" \
  "https://${EXISTING_TEST_DOMAIN}/" -o /dev/null -w '%{http_code}')
printf '原网站基线状态码：%s\n' "$existing_status"
printf '%s\n' "$existing_status" | grep -Eq '^[1-5][0-9][0-9]$' || { echo '原网站基线检查失败'; exit 1; }
cat > "$root_dir/vps/coexist.env" <<EOF
EDGE_BIND_ADDRESS=$edge_ip
VAULT_DOMAIN=$VAULT_DOMAIN
NOTES_DOMAIN=$NOTES_DOMAIN
NAS_TAILSCALE_IP=$NAS_TAILSCALE_IP
NAS_TLS_PORT=8443
EXISTING_TLS_ADDRESS=127.0.0.1:443
NGINX_SITE=$nginx_site
EXISTING_TEST_DOMAIN=$EXISTING_TEST_DOMAIN
EXISTING_EXPECTED_STATUS=$existing_status
EOF
chmod 600 "$root_dir/vps/coexist.env"
echo "已识别公网网卡 $edge_ip，Nginx 配置 $nginx_site。"
exec sh "$root_dir/scripts/bootstrap-vps-coexist.sh"
