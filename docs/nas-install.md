# NAS 部署

1. 确认 Tailscale 直接运行在 NAS 主机网络中，并获得稳定的 Tailscale IPv4。
2. 将仓库放在持久化存储卷中，进入 `nas` 目录。
3. 创建配置：

   ```sh
   cp .env.example .env
   chmod 600 .env
   ```

4. 填写域名、NAS Tailscale IP 和随机数据库密码。创建 nas/secrets 目录，将 Cloudflare Token 保存为 secrets/cloudflare-token.txt，目录权限 700、文件权限 600。Caddy 通过只读挂载使用该文件。
5. 构建带 Cloudflare DNS 模块的 Caddy 并启动：

   ```sh
   docker compose build --pull caddy
   docker compose pull
   docker compose up -d
   docker compose ps
   docker compose logs caddy
   ```

6. Caddy 仅监听本机 127.0.0.1:18443。若 Tailscale 运行在 host 网络模式的容器中，执行 `docker exec tailscale tailscale serve --bg --tcp=8443 tcp://127.0.0.1:18443`，增加原始 TCP 转发。不要使用 reset，也不要覆盖现有 443 配置。主机直接安装 Tailscale 时使用相同 Serve 参数。
7. 打开 Joplin Server 管理页面，立即修改默认管理员密码，然后建立一个独立的普通同步用户。
8. Vaultwarden 不配置 `ADMIN_TOKEN`，Caddy 也会让公网 `/admin` 返回 404。所有设置通过版本化环境变量管理。

容器的数据库网络为 Docker internal network，PostgreSQL 没有宿主机端口映射。
