### 答案

完整时间线：
10:00:01 - Failed login admin (SSH)
10:01:14 - Failed login student (SSH)
10:03:01 - GET /backup/db-backup.txt (nginx)
10:04:52 - Accepted student login (SSH)
10:07:20 - GET /login?user=admin (incident)
10:09:44 - GET /admin/export (incident, 数据导出)

初始入侵：student账户弱密码暴力破解成功。
攻击链：SSH登录 -> 访问备份 -> 尝试Web登录 -> 数据导出。