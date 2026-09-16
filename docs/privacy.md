# 发布隐私检查

公开仓库只使用示例域名、示例 Tailscale 地址和占位凭据。真实域名保存在被忽略的 .private/domain 及两个被忽略的 .env 文件中。

本仓库使用 .githooks/pre-commit 检查暂存内容，阻止真实域名、Tailscale Auth Key、Cloudflare Token 和数据库密码进入提交。克隆仓库后执行 git config core.hooksPath .githooks 启用。

发布前还应检查 git status --short，搜索真实域名，并查看即将发布的完整 Git 历史。

如果秘密曾经进入 Git 历史，仅删除当前文件不够；应立即撤销对应 Token，并重写历史后再发布。
