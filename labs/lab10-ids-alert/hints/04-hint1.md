### 提示

用 jq 按严重度分组：
```
jq -s 'group_by(.alert.severity)' evidence/ids/eve.json
```