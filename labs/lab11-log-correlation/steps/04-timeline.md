# TITLE: 时间线 — 构建关联时间线
# STEP: 4
# MINUTES: 12

### WHY

时间线是事件调查的核心工具。按时间排序所有事件，你会发现：
- 攻击是如何开始的
- 攻击者做了什么
- 哪些事件是相关的

### DO

1. 从各日志中提取时间戳和事件：
```
grep -h "." logs/nginx/access.log logs/traffic/traffic.log 2>/dev/null | sort
```

2. 手工构建一个时间排序的表格：

| 时间 | 来源 | 事件 |
|------|------|------|
| 10:02:31 | nginx | GET /backup/db-backup.txt |
| 10:03:01 | traffic | GET /beacon?id=101 |
| ... | ... | ... |

3. 合并相关事件，识别事件链

### CHECK

- 你构建的时间线中有多少个事件？
- 哪些事件看起来是相关的？
