# 前置准备

## Cloudflare

创建两个 DNS 记录：

- `vault.example.com` 指向 VPS 公网 IPv4。
- `notes.example.com` 指向 VPS 公网 IPv4。

初次部署建议使用 DNS only（灰云），确认工作后仍建议保持灰云。Cloudflare 橙云会在 Cloudflare 边缘终止 TLS，与“VPS 不解密、NAS 持有证书”的信任模型不同。

创建一个专用 API Token，权限仅包括：

- Zone / DNS / Edit
- Zone / Zone / Read

Zone Resources 只选择实际使用的域名。不要使用 Global API Key。

## 网络与系统

- VPS：Ubuntu 24.04、Docker Engine、Docker Compose Plugin、Tailscale。
- NAS：绿联 Docker/容器管理器、Docker Compose、Tailscale。
- VPS 安全组仅放行公网 TCP 80 和 443。SSH 建议只通过 Tailscale 访问。
- 家庭路由器不需要任何端口转发。
- 记录 NAS 的 Tailscale IPv4 地址。

## Tailscale 标签

为 VPS 分配 `tag:vps-gateway`，为 NAS 分配 `tag:nas-services`。应用策略前，先使用策略中的 `tests` 检查端口隔离。

