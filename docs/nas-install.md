# NAS 部署

1. 确认 Tailscale 直接运行在 NAS 主机网络中，并获得稳定的 Tailscale IPv4。
2. 将仓库放在持久化存储卷中，进入 `nas` 目录。
3. 创建配置：

   ```sh
   cp .env.example .env
   chmod 600 .env
   ```

4. 填写域名、Cloudflare Token、NAS Tailscale IP 和随机数据库密码。
5. 构建带 Cloudflare DNS 模块的 Caddy 并启动：

   ```sh
   docker compose build --pull caddy
   docker compose pull
   docker compose up -d
   docker compose ps
   docker compose logs caddy
   ```

6. 确认宿主机只在 Tailscale IP 的 TCP 8443 上监听。若绿联系统或 Docker 版本无法绑定该地址，改为绑定 `0.0.0.0:8443` 时，必须使用 NAS 防火墙限制来源接口/地址，只允许 Tailscale 网络访问。
7. 打开 Joplin Server 管理页面，立即修改默认管理员密码，然后建立一个独立的普通同步用户。
8. Vaultwarden 不配置 `ADMIN_TOKEN`，Caddy 也会让公网 `/admin` 返回 404。所有设置通过版本化环境变量管理。

容器的数据库网络为 Docker internal network，PostgreSQL 没有宿主机端口映射。

