# VPS 部署

以下命令在 Ubuntu 24.04 VPS 上执行。

1. 安装 Docker Engine、Compose Plugin 和 Tailscale。
2. 使用带 `tag:vps-gateway` 的一次性、预授权 Auth Key 加入 tailnet；完成后立即吊销或让密钥自动过期。
3. 将仓库复制到 VPS，进入 `vps` 目录。
4. 复制并编辑环境文件：

   ```sh
   cp .env.example .env
   chmod 600 .env
   ```

5. 填写 NAS 的 Tailscale IPv4，然后启动：

   ```sh
   docker compose pull
   docker compose up -d
   docker compose ps
   ```

6. 确认 VPS 能连接 NAS：

   ```sh
   tailscale ping <NAS_TAILSCALE_IP>
   curl -vk --resolve vault.example.com:8443:<NAS_TAILSCALE_IP> https://vault.example.com:8443/alive
   ```

HAProxy 只做 TCP 转发。它不会读取域名证书或 HTTP 内容。端口 80 只执行 HTTPS 跳转。
