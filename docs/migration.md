# 迁移现有数据

## Vaultwarden

如果继续使用原来的 Vaultwarden 数据：

1. 停止旧 Vaultwarden，防止迁移时继续写入。
2. 完整复制旧 `/data` 内容到 `nas/data/vaultwarden/`，包括数据库、附件、发送文件和密钥文件。
3. 保留原始目录的只读副本。
4. 启动新 Vaultwarden，使用一个客户端验证登录、附件、TOTP 和同步。
5. 确认所有客户端正常后再退役旧实例。

不要通过普通文件复制一个仍在写入的 SQLite 数据库。迁移前另行从桌面客户端导出一份加密 JSON，作为应用层应急备份。

## Joplin：WebDAV 到 Joplin Server

1. 暂停手机和其他电脑上的 Joplin，不再编辑笔记。
2. 在当前完整的桌面客户端执行一次 WebDAV 同步，确认同步状态没有错误。
3. 导出完整 JEX 文件，并复制整个 Joplin profile 目录作为第二份备份。
4. 部署 Joplin Server，修改默认管理员密码，创建普通同步用户。
5. 推荐建立一个临时的全新桌面 profile，导入 JEX，并把同步目标设为 Joplin Server。
6. 完成首次上传后检查笔记、笔记本、标签、附件、待办事项和 E2EE 状态。
7. 在另一台设备使用全新 profile 从 Joplin Server 下载，验证恢复结果。
8. 验证完成后，其他客户端逐台改用 Joplin Server。不要让客户端同时对 WebDAV 和 Joplin Server 写入。
9. 将旧 WebDAV 目录保留为只读归档，至少跨过一个完整备份周期后再考虑清理。

如果原来已经开启 E2EE，保留主密钥密码。迁移不会替你恢复遗失的 E2EE 密钥。

JEX 不包含笔记历史；因此必须保留完整 profile 备份和旧 WebDAV 数据。完成另一台设备的恢复验证之前，不删除原 profile。

### 保留 Vaultwarden 旧 Tailscale 地址

旧容器停止后，可使用 `docker compose -f compose.yaml -f compose.compat.yaml up -d --no-build vaultwarden`，将新实例绑定到主机回环地址的 8080 端口，再把现有 Tailscale Serve HTTPS 代理指向 `http://127.0.0.1:8080`。旧地址和新域名由此使用同一数据库。日后更新时继续包含这个 override 文件，直到所有客户端都迁移完成。
