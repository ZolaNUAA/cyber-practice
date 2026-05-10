# TITLE: 证据收集 — 从多源收集证据
# STEP: 3
# MINUTES: 12

### WHY

证据收集必须系统化，避免遗漏。从最容易获取的开始，逐步深入。

**证据来源层次**：
1. 预置证据（静态副本）
2. 运行时日志（可能被篡改）
3. 应用服务（实时访问）
4. Docker 容器日志

### DO

1. 查看预置证据：
```
ls -la evidence/incident/
cat evidence/incident/web-access.log
cat evidence/incident/auth.log
```

2. 查看运行时日志：
```
tail -20 logs/nginx/access.log
tail -20 logs/incident/incident.log
```

3. 实时访问事件服务：
```
curl http://127.0.0.1:8092/
curl "http://127.0.0.1:8092/login?user=admin&password=wrong"
curl http://127.0.0.1:8092/admin/export
```

### CHECK

- 收集了多少条日志？
- 预置证据和运行时日志有什么不同？
