# TITLE: 受影响资产 — 账户与路径分析
# STEP: 6
# MINUTES: 10

### WHY

了解"什么被影响了"才能确定修复范围。

**受影响资产**：
- 账户：student（密码 Student123）
- 路径：/backup/db-backup.txt（信息泄露）
- 应用：incident-lab 的 /admin/export（数据导出）

### DO

1. 列出所有受影响的账户：
   - `student` — 密码被暴力破解
   - `admin` — 被尝试过登录
   - `dev` — 硬编码凭证（Dev123）

2. 列出受影响的服务和路径：
   - SSH 服务（端口 2222）
   - Nginx `/backup/` 目录
   - incident-lab `/admin/export` 端点

### CHECK

- 受影响资产清单完整吗？
- 哪些是最关键的资产？
