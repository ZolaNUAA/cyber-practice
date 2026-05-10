# TITLE: 读取 — 查看 EVE.json 告警文件
# STEP: 2
# MINUTES: 8

### WHY

Suricata EVE 格式是行业标准的 IDS 告警格式。每条告警是一个 JSON 对象。

### DO

1. 启动实验：
```
cd ~/cyber-practice
./reset-lab.sh lab10
```

2. 查看告警文件内容：
```
cat evidence/ids/eve.json
```

3. 用 jq 格式化查看：
```
jq . evidence/ids/eve.json
```

4. 统计告警数量：
```
jq -s 'length' evidence/ids/eve.json
```

### CHECK

- 总共有几条告警？
- 每条告警包含哪些关键字段？
