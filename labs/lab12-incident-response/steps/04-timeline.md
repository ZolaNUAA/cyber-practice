# TITLE: 时间线 — 构建攻击时间线
# STEP: 4
# MINUTES: 15

### WHY

时间线告诉你攻击者做了什么、什么时候做的、按照什么顺序。

**构建方法**：
1. 从所有日志源提取时间戳
2. 合并并按时间排序
3. 标注每个事件的意义

### DO

汇总所有来源的事件，构建时间线：

| 时间 | 来源 | 事件 | 意义 |
|------|------|------|------|
| 10:00:01 | auth.log | Failed login admin | 尝试管理员账户 |
| 10:01:14 | auth.log | Failed login student | 尝试普通账户 |
| 10:03:01 | web-access | GET /backup/db-backup.txt | 访问备份文件 |
| 10:04:52 | auth.log | Accepted student | 成功登录 |
| 10:07:20 | web-access | GET /login?user=admin | 尝试管理员登录 |
| 10:09:44 | web-access | GET /admin/export | 数据导出 |

### CHECK

- 时间线有多少个事件？
- 事件之间的时间间隔是多少？
