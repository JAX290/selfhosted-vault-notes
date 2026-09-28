# Self-hosted Vaultwarden + Joplin Server

一套面向个人和家庭使用的可复制部署：公网请求进入 Ubuntu VPS，经 Tailscale 转发到 NAS；TLS 在 NAS 上终止，VPS 不保存证书，也不解密应用流量。

```text
Internet
   |
   | vault.example.com / notes.example.com (TCP 443)
   v
Ubuntu 24.04 VPS: HAProxy TCP passthrough
   |
   | Tailscale, only TCP 8443
   v
UGREEN NAS: Caddy (Cloudflare DNS-01)
   |-- Vaultwarden
   `-- Joplin Server -- PostgreSQL
```

## 设计原则

- VPS 无状态，只保存公开配置；更换 VPS 后修改 Cloudflare A/AAAA 记录即可。
- NAS 是唯一数据节点，证书由 NAS 上的 Caddy 使用 Cloudflare DNS-01 自动维护。
- Vaultwarden 使用 SQLite，适合个人/家庭规模并降低恢复复杂度。
- Joplin 使用专用的 Joplin Server 和 PostgreSQL。
- PostgreSQL、Vaultwarden 和 Joplin Server 均不发布宿主机端口。
- 应用 Tailscale Grants 并移除重叠的宽泛授权后，VPS 只能访问 NAS 的 TCP 8443；部署服务本身不会自动修改整个 tailnet 的策略。
- 镜像版本通过 `.env` 显式指定，升级前先备份。

## 快速开始

1. 阅读 [前置准备](docs/prerequisites.md)。
2. 按 [NAS 部署](docs/nas-install.md) 部署应用和 HTTPS。
3. 按 [VPS 部署](docs/vps-install.md) 部署公网入口。
4. 应用 [Tailscale Grants](tailscale/grants.example.hujson)。
5. 修改 Cloudflare DNS 后执行 `scripts/health-check.sh`。
6. 按 [迁移说明](docs/migration.md) 迁移现有 Vaultwarden 和 Joplin。

公开发布前阅读 [隐私检查](docs/privacy.md)。真实域名只应存在于被 Git 忽略的本地配置中。

更换服务器按 [VPS 重部署](docs/replace-vps.md) 操作。干净 Ubuntu VPS 可使用原生 HAProxy 初始化脚本；有现有网站时使用共存配置。

## 新 VPS 快速部署（NAS 已部署）

适用于全新的 Ubuntu 24.04 VPS。NAS 上的应用、数据和证书保持原位置，无需重新部署 NAS。先保留旧 VPS。

### 推荐：统一一键入口

新 VPS 已安装并认证 Tailscale 后，以 root 执行：

```bash
apt-get update && apt-get install -y git
git clone https://github.com/JAX290/selfhosted-vault-notes.git /root/selfhosted-vault-notes 2>/dev/null || \
  git -C /root/selfhosted-vault-notes pull --ff-only
sh /root/selfhosted-vault-notes/scripts/install-vps-gateway.sh
```

脚本询问 NAS 的 Tailscale IPv4。若发现公网 80/443 空闲，会选择独立模式；若发现已有 Nginx 和系统 HAProxy，会识别公网网卡、原 Nginx 站点，询问两个应用域名后使用共存模式。共存模式不修改系统 HAProxy 配置和挖矿端口，失败时恢复 Nginx。真实地址只写入被 Git 忽略的私有配置。

### VPS 已安装并认证 Tailscale

如果新 VPS 已加入 NAS 所在的同一个 tailnet，使用 root 直接执行以下完整命令：

```bash
apt-get update
apt-get install -y git
git clone https://github.com/JAX290/selfhosted-vault-notes.git /root/selfhosted-vault-notes
cd /root/selfhosted-vault-notes

cp vps/host.env.example vps/host.env
sed -i 's/^NAS_TAILSCALE_IP=.*/NAS_TAILSCALE_IP=100.64.0.10/' vps/host.env
sh scripts/bootstrap-vps.sh
```

无需再次运行 `tailscale up`。脚本会安装 HAProxy、写入网关服务并立即启动。成功时显示 `Gateway started; validate HTTPS before changing DNS`。

如果仓库已经下载过，只需执行：

```bash
cd /root/selfhosted-vault-notes
git pull --ff-only
cp -n vps/host.env.example vps/host.env
sed -i 's/^NAS_TAILSCALE_IP=.*/NAS_TAILSCALE_IP=100.64.0.10/' vps/host.env
sh scripts/bootstrap-vps.sh
```

上面的 `100.64.0.10` 是示例地址，执行前必须替换为自己 NAS 的 Tailscale IPv4。NAS 更换节点或 Tailscale IPv4 发生变化时，应填写新地址。

### VPS 尚未安装或认证 Tailscale

先按上一节运行部署命令。首次执行会安装 Tailscale；若提示未登录，执行：

```bash
tailscale up
```

打开命令输出的授权链接，将新 VPS 加入 NAS 所在的同一个 tailnet。确认访问策略允许新 VPS 连接 NAS 的 TCP 8443，再执行：

```bash
cd /root/selfhosted-vault-notes
sh scripts/bootstrap-vps.sh
systemctl status vault-notes-edge --no-pager
```

确保 VPS 防火墙和云厂商安全组允许 TCP 80、443。修改 DNS 前，填写新 VPS 公网 IP 和现有的两个真实域名，验证 HTTPS：

```bash
read -r -p '新 VPS 公网 IPv4: ' NEW_IP
read -r -p 'Vaultwarden 域名（不含 https://）: ' VAULT_DOMAIN
read -r -p 'Joplin 域名（不含 https://）: ' NOTES_DOMAIN

curl --fail --resolve "$VAULT_DOMAIN:443:$NEW_IP" "https://$VAULT_DOMAIN/alive"
curl --fail --resolve "$NOTES_DOMAIN:443:$NEW_IP" "https://$NOTES_DOMAIN/api/ping"
```

两项均通过后，将 Cloudflare 中这两个域名的 A 记录改为新 VPS 公网 IPv4，保持灰云（仅 DNS）。如存在指向旧 VPS 的 AAAA 记录，需同步处理，避免客户端仍通过 IPv6 访问旧节点。验证电脑和手机同步正常后，再退役旧 VPS 并移除旧 Tailscale 节点。

APP 的服务器地址、账户和密码保持不变。真实域名和 NAS IP 只填写在本机配置中，不提交到 GitHub。脚本会拒绝在已有 80/443 监听的服务器上部署；详细流程见 [更换 VPS](docs/replace-vps.md)。

### VPS 已有网站、挖矿中转或其他 HAProxy 服务

不要运行独立模式脚本，也不要修改已有挖矿端口。共存模式让原 Nginx 保留 `127.0.0.1:443`，新的独立 HAProxy 仅接管公网网卡的 443，并按 TLS SNI 分流：两个应用域名转到 NAS `8443`，其他域名回到原 Nginx。原系统 HAProxy 及其挖矿端口不变。

先检查现有 Nginx 配置，确认其同时有回环 443 和一个明确的公网网卡 443 监听；本脚本不支持只有 `0.0.0.0:443` 的未经审查配置。然后执行：

```bash
cd /root/selfhosted-vault-notes
git pull --ff-only
cp vps/coexist.env.example vps/coexist.env
nano vps/coexist.env
sh scripts/bootstrap-vps-coexist.sh
```

填写 VPS 网卡地址、两个域名、NAS Tailscale 地址、原 Nginx 配置文件及原网站预期状态码。脚本先验证 NAS、Nginx 和系统 HAProxy，备份 Nginx 配置，再切换公网 443；任一健康检查失败会恢复原 Nginx 配置。`vps/coexist.env` 被 Git 忽略。

## 重要目录

| 路径 | 用途 |
| --- | --- |
| `vps/` | Ubuntu VPS 上的 HAProxy TCP 转发栈 |
| `nas/` | NAS 上的 Caddy、Vaultwarden、Joplin Server 和 PostgreSQL |
| `tailscale/` | 最小权限策略模板 |
| `scripts/` | 配置检查、健康检查和停机一致性备份 |
| `docs/` | 安装、迁移、备份恢复和升级说明 |

## 仓库与秘密

`.env`、应用数据和备份已由 `.gitignore` 排除。Cloudflare Token、数据库密码、Tailscale Auth Key 和真实数据不得提交，即使仓库是私有仓库。

此仓库不会自动执行升级。先阅读发行说明、备份并验证恢复路径，再修改镜像版本。
