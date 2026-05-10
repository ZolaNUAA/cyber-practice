# TITLE: 文件权限审计 — 敏感文件发现
# STEP: 3
# MINUTES: 10

### WHY

文件权限配置错误可能导致敏感信息泄露。关键检查点：
- `/opt/` 下的应用文件
- `/etc/` 下的配置文件
- 备份目录
- `.env` 和 `.conf` 文件

### DO

1. 检查 `/opt` 下的文件：
```
find /opt -maxdepth 3 -type f -ls
```

2. 查看你能否读取 `/opt/backups/app.env`：
```
cat /opt/backups/app.env
```

3. 检查文件权限：
```
ls -la /opt/backups/
```

4. 记录任何你能读取但"不应该"能读取的文件

### CHECK

- 找到了什么敏感信息？
- 哪些文件的权限你认为不合理？
