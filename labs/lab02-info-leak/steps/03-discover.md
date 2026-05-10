# TITLE: 发现 — 暴露的 backup 目录
# STEP: 3
# MINUTES: 10

### WHY

目录浏览功能允许用户看到目录下所有文件。在生产环境中这是严重安全问题。

### DO

1. 访问暴露的目录：
```
curl http://127.0.0.1:8082/backup/
```

2. 查看泄露文件：
```
curl http://127.0.0.1:8082/backup/db-backup.txt
curl http://127.0.0.1:8082/backup/old-config.conf
```

3. 记录敏感信息：数据库连接、调试配置、密码提示

### CHECK

找到了什么敏感信息？
