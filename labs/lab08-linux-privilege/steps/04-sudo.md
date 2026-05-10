# TITLE: sudo 规则分析 — 权限边界审查
# STEP: 4
# MINUTES: 10

### WHY

sudo 配置不当是最常见的权限提升途径。检查项：
- 哪些命令可以 sudo 执行？
- 是否需要密码？
- 命令是否可被滥用？

**危险的 sudo 规则示例**：
- `ALL=(ALL) NOPASSWD: ALL` — 等同于 root
- `/usr/bin/vim` — vim 可以执行 shell 命令（`:!bash`）
- `/bin/cp` — 可以覆盖关键系统文件
- `/usr/bin/find` — `find` 的 `-exec` 可以执行任意命令

### DO

1. 查看 sudo 权限：
```
sudo -l
```

2. 运行允许的备份命令：
```
sudo /usr/local/bin/backup-app
```

3. 检查备份脚本内容：
```
cat /usr/local/bin/backup-app
```

### CHECK

- sudo -l 显示了什么？
- `backup-app` 脚本做了什么？
- 这个 sudo 规则安全吗？有可能被滥用吗？
