# TITLE: Scope — 定义事件范围
# STEP: 2
# MINUTES: 8

### WHY

事件响应的第一步是确定范围：什么系统被影响了？影响了多久？

**范围界定问题**：
- 哪些 IP/主机被涉及？
- 攻击发生的时间窗口？
- 涉及哪些服务/应用？
- 有数据泄露吗？

### DO

1. 启动实验：
```
cd ~/cyber-practice
./reset-lab.sh lab12
```

2. 确定可用资源：
   - 事件服务：http://127.0.0.1:8092
   - Nginx 服务器：http://127.0.0.1:8082
   - 证据目录：`evidence/incident/`
   - 运行时日志：`logs/incident/`, `logs/nginx/`

3. 在报告中写下初始范围：
```
本事件调查涉及：127.0.0.1 上的 incident-lab (8092)、nginx-lab (8082)
时间窗口：基于日志时间戳确定
```

### CHECK

- 列出了所有相关的系统吗？
- 你有多少条日志来源？
