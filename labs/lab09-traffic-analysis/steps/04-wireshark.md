# TITLE: 分析 — 用 Wireshark 查看数据包
# STEP: 4
# MINUTES: 12

### WHY

Wireshark 让你能直观地看到每个数据包的细节——从链路层到应用层。

**关键操作**：
- 过滤器：`http`、`tcp.port==8089`、`http.request.method==GET`
- Follow TCP Stream：右键 → Follow → TCP Stream，看到完整的请求/响应
- 统计 → 会话：按流量大小排序

### DO

1. 打开 PCAP 文件：
```
wireshark pcaps/lab09.pcap &
```

2. 应用过滤器：
   - 只显示 HTTP：输入 `http` → 回车
   - 只看 8089 端口：`tcp.port == 8089`

3. 选择一个 HTTP 请求，右键 → Follow → HTTP Stream

4. 观察每个请求的：
   - HTTP 方法（GET）
   - URI 路径
   - User-Agent
   - 响应状态码

### CHECK

- 你能找到 3 个不同的请求吗（`/`, `/api/status`, `/beacon`）？
- 截图保存 Follow Stream 的结果
