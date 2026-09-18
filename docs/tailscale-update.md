# Tailscale 容器自动更新

使用 `scripts/update-tailscale-container.sh` 配合 NAS 用户 crontab。执行用户需有 Docker 权限，依赖 Compose、Python 3、curl、flock 和 timeout。

创建私有的 `tailscale-update.env`（不要提交 Git）：

```sh
COMPOSE_DIR=/path/to/tailscale
BACKUP_DIR=/path/to/private-backups/tailscale-update
IMAGE=tailscale/tailscale:stable
CONTAINER=tailscale
SERVICE=tailscale
VAULT_URL=https://vault.example.com
NOTES_URL=https://notes.example.com
```

脚本读取原目录的 `docker-compose.yaml`，通过单独 override 选择 stable 镜像。原网络、状态挂载和其他参数保持不变。若今后手动重建，需同时使用备份目录中的 `update.override.yaml`，或将原 Compose 镜像改成相同 stable 地址，以免退回旧镜像。

先执行 `sh scripts/update-tailscale-container.sh /path/to/tailscale-update.env --check`，验证配置但不下载或重启。然后设置每周日 04:00 的 cron，使用完整脚本与配置路径，将日志重定向到私有备份目录。调度时间使用 NAS 本机时区。

有新镜像时，停止容器并备份完整状态，重建后比较原 Tailscale IPv4 和 Serve 配置，再验证两个应用的 HTTPS。下载失败不重启容器，健康检查失败尝试恢复旧镜像。状态备份含设备私钥，必须限制权限并另存加密备份；不要自动清理仍有恢复用途的快照。

旧镜像恢复不等于完整状态恢复。若新版改变状态格式、旧版无法启动，需要人工从快照恢复状态。外部网络故障也可能触发健康检查回滚，可查看日志判断。

NAS 更新后，旧的 SSH 连接可能断开；cron 任务独立运行，无需电脑保持在线。自动更新设置不修改 Vaultwarden、Joplin 或 PostgreSQL。
