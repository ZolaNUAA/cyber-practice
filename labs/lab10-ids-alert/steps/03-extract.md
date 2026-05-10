# TITLE: 提取 — 关键字段解析
# STEP: 3
# MINUTES: 10

### WHY

告警分析的第一步是提取关键字段，快速了解"发生了什么"。

**关键字段**：
- `timestamp`：发生时间
- `src_ip` / `dest_ip`：源和目标 IP
- `alert.signature`：告警名称
- `alert.category`：攻击类别
- `alert.severity`：严重度（1=最高, 3=最低）
- `http.url`：涉及的 URL

### DO

1. 提取时间戳和告警名称：
```
jq -r '[.timestamp, .alert.signature] | @tsv' evidence/ids/eve.json
```

2. 提取源和目标：
```
jq -r '[.src_ip, .dest_ip, .dest_port, .alert.signature] | @tsv' evidence/ids/eve.json
```

3. 提取 HTTP 信息：
```
jq -r '[.timestamp, .alert.signature, .http.url] | @tsv' evidence/ids/eve.json
```

### CHECK

- 告警涉及哪些端口？
- 攻击类型有哪些？
