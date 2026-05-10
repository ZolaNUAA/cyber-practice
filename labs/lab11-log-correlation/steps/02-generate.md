# TITLE: 生成流量 — 创造可分析的日志
# STEP: 2
# MINUTES: 8

### WHY

先制造一些活动，才能在日志中看到痕迹。

### DO

1. 启动实验：
```
cd ~/cyber-practice
./reset-lab.sh lab11
```

2. 访问 Nginx 的敏感路径：
```
curl http://127.0.0.1:8082/backup/db-backup.txt
curl http://127.0.0.1:8082/status.html
```

3. 访问 Traffic Lab：
```
curl "http://127.0.0.1:8089/beacon?id=101"
curl http://127.0.0.1:8089/api/status
```

### CHECK

- 发送了多少个请求？
- 你访问了哪些不同的端点？
