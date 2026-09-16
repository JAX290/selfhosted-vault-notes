# 备份与恢复

同步不能替代备份。建议执行 3-2-1：至少三份数据、两种介质、一份异地加密副本。

## 备份内容

- Vaultwarden：完整 `nas/data/vaultwarden`。
- Joplin：PostgreSQL 自定义格式 dump。
- Caddy：`nas/data/caddy` 可备份，但证书可以重新签发。
- 配置：仓库版本、实际 `.env` 的加密副本、Tailscale 策略。
- 客户端：定期导出 Vaultwarden 加密 JSON 和 Joplin JEX。

运行：

```sh
BACKUP_ROOT=/path/to/encrypted-storage ./scripts/backup.sh
```

脚本会短暂停止 Vaultwarden，以获得 SQLite 和附件的一致副本；Joplin 使用 `pg_dump` 在线备份。生成的目录本身没有加密，目标路径应位于加密存储中。

## 恢复演练

至少每季度在隔离环境执行一次：

1. 使用备份恢复 Vaultwarden 数据目录。
2. 启动空 PostgreSQL，通过 `pg_restore --clean --if-exists` 恢复 Joplin dump。
3. 使用临时域名或本地 hosts 文件验证登录和附件。
4. 记录恢复时长和缺失项。

恢复生产环境前先停止应用写入，并保留当前损坏状态的快照，以便二次取证或补救。

