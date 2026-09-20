# 更换 VPS

NAS 数据、证书和 Cloudflare Token 不需要迁移。先保留旧 VPS。

1. 在新 Ubuntu 24.04 VPS 拉取公开仓库。
2. 复制 vps/host.env.example 为 vps/host.env，填写 NAS Tailscale IP；该文件被 Git 忽略。
3. root 执行 sh scripts/bootstrap-vps.sh。脚本拒绝覆盖已占用的 80/443 端口。
4. 如提示未登录 Tailscale，执行 tailscale up，在浏览器授权加入原来的 tailnet，再运行脚本。只有在配置好标签所有者和 Grants 后才使用 --advertise-tags=tag:vps-gateway。
5. 使用 curl --resolve 把两个域名临时指定到新 VPS，验证证书、Vaultwarden /alive 和 Joplin /api/ping。
6. 两项健康检查通过后，修改 Cloudflare A 记录，保持灰云。
7. 验证手机与电脑同步后，退役旧 VPS 并移除旧 Tailscale 节点。

有现有网站、挖矿中转或系统 HAProxy 的 VPS，先人工核对网卡绑定和原网站回环监听，再填写 `vps/coexist.env` 并运行 `sh scripts/bootstrap-vps-coexist.sh`。该脚本使用独立服务，不覆盖系统 HAProxy 配置，也不修改挖矿端口。
