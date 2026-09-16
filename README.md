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
- VPS 通过 Tailscale Grants 只能访问 NAS 的 TCP 8443。
- 镜像版本通过 `.env` 显式指定，升级前先备份。

## 快速开始

1. 阅读 [前置准备](docs/prerequisites.md)。
2. 按 [NAS 部署](docs/nas-install.md) 部署应用和 HTTPS。
3. 按 [VPS 部署](docs/vps-install.md) 部署公网入口。
4. 应用 [Tailscale Grants](tailscale/grants.example.hujson)。
5. 修改 Cloudflare DNS 后执行 `scripts/health-check.sh`。
6. 按 [迁移说明](docs/migration.md) 迁移现有 Vaultwarden 和 Joplin。

公开发布前阅读 [隐私检查](docs/privacy.md)。真实域名只应存在于被 Git 忽略的本地配置中。

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
