# 线路看门狗

看门狗每两分钟检查一次，连续两次失败后才执行恢复，避免短暂丢包导致服务反复重启。

## VPS

VPS 检查 Tailscale、NAS 的 8443 入口及独立的 `vault-notes-edge`。恢复顺序是先重启 Tailscale，再按需重启 `vault-notes-edge`。它不会重启或修改系统 HAProxy，因此不会影响已有的挖矿中转端口。

```bash
cd /root/selfhosted-vault-notes
git pull --ff-only
sh scripts/install-vps-watchdog.sh
```

查看状态和最近日志：

```bash
systemctl status vault-notes-watchdog.timer --no-pager
journalctl -u vault-notes-watchdog.service -n 50 --no-pager
```

## NAS

NAS 检查 Vaultwarden、Joplin、Caddy 和 Tailscale 容器。连续失败后重新应用现有 Compose 配置；若发现旧版 `vaultwarden` 容器，会先取消它的自动启动并停止它，防止再次抢占 8080 端口。脚本不会删除旧容器或数据。

需要使用有权写入系统计划任务的 NAS 管理员或 root 账户执行：

```bash
cd /volume1/docker/vault-notes
sh scripts/install-nas-watchdog.sh
```

查看记录：

```bash
tail -n 100 /volume1/docker/vault-notes/secrets/watchdog.log
```

看门狗只执行本机恢复。若 NAS 断电、VPS 宕机或运营商线路长期中断，它会留下日志，但无法替代异地监控和告警。
