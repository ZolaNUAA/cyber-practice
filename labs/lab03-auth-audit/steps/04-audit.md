# TITLE: 审计 — 查看 SSH 登录日志
# STEP: 4
# MINUTES: 10

### WHY

日志审计是安全运维的核心。每一次登录——无论成功还是失败——都会在系统日志中留下痕迹。

**SSH 日志的关键位置**：
- Docker 容器日志：`docker logs ssh-lab`
- 系统日志：`/var/log/auth.log`（容器内）
- 这些日志可用于检测暴力破解和异常登录

### DO

1. 查看 Docker 日志中的 SSH 活动：
```
docker logs ssh-lab 2>&1 | tail -n 50
```

2. 找一找日志中的关键信息：
   - `Failed password` — 失败的登录尝试
   - `Accepted password` — 成功的登录
   - `invalid user` — 尝试不存在的用户
   - 来源 IP 和端口

3. 统计失败尝试次数：
```
docker logs ssh-lab 2>&1 | grep "Failed password" | wc -l
```

### CHECK

- 你能在日志中找到自己刚才的登录记录吗？
- Failed 和 Accepted 分别有几条？
