# TITLE: 收集 — 多源日志汇总
# STEP: 3
# MINUTES: 10

### WHY

日志分散在不同位置，第一步是找到它们并了解格式。

### DO

1. 列出所有日志文件：
```
find logs evidence/logs -type f -maxdepth 3 -print
```

2. 查看每个日志的内容：
```
tail -10 logs/nginx/access.log
tail -10 logs/traffic/traffic.log
```

3. 观察日志格式的差异：
   - Nginx：标准 Apache 格式
   - Traffic：自定义时间戳格式

### CHECK

- 有多少个日志源？
- 每种日志的格式有什么不同？
