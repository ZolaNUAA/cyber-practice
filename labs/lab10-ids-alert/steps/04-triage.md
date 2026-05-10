# TITLE: 分级 — 按严重度排序与优先级判定
# STEP: 4
# MINUTES: 10

### WHY

Triage（分诊）是安全运维的关键流程。面对海量告警，你需要快速判断：
- 哪些是误报（false positive）
- 哪些需要立即处理
- 哪些可以延后

**分级标准**：
1. 严重度 1 — 立即响应（如命令注入成功）
2. 严重度 2 — 4 小时内调查（如信息泄露尝试）
3. 严重度 3 — 24 小时内复查（如扫描探测）

### DO

1. 按严重度分组：
```
jq -r 'group_by(.alert.severity)[] | "Severity \(.[0].alert.severity): \(length) alerts"' evidence/ids/eve.json
```

2. 列出最高严重度的告警：
```
jq 'select(.alert.severity == 1)' evidence/ids/eve.json
```

3. 决定哪个应该最先处理，解释原因。

### CHECK

- 哪个告警应该最先被 triage？为什么？
- 如果你是 SOC 分析师，你会怎么处理这些告警？
