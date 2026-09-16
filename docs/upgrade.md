# 升级流程

不要使用自动更新容器直接替换生产镜像。

1. 阅读 Vaultwarden、Joplin Server、PostgreSQL、Caddy 和 HAProxy 的发行说明。
2. 执行并异地复制备份。
3. 修改 `.env` 中的明确镜像版本；Caddy 升级还需同步修改 `nas/compose.yaml` 的 build 参数与 image 标签。
4. 拉取或构建镜像：

   ```sh
   docker compose pull
   docker compose build --pull caddy
   ```

5. 检查渲染配置：

   ```sh
   docker compose config --quiet
   ```

6. 在维护窗口执行 `docker compose up -d`。
7. 检查容器日志、公开健康端点、Vaultwarden 客户端同步和 Joplin 附件同步。
8. 保留旧镜像和最近备份，直到跨过观察期。

PostgreSQL 大版本升级不能只修改镜像标签。应使用 `pg_dump`/`pg_restore` 或官方 `pg_upgrade` 流程迁移。
