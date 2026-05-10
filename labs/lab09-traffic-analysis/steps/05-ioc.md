# TITLE: IOC — 提取威胁指标
# STEP: 5
# MINUTES: 10

### WHY

IOC（Indicator of Compromise，入侵指标）是威胁情报的核心。从流量中提取的 IOC 包括：
- 恶意 IP 地址
- 可疑域名
- 异常 User-Agent
- 特殊的 URI 模式（如 `/beacon?id=101` 看起来像 C2 通信）

### DO

1. 从 Wireshark 或 tshark 中提取信息：
```
tshark -r pcaps/lab09.pcap -T fields   -e ip.src -e ip.dst -e http.request.method   -e http.request.uri -e http.user_agent
```

2. 构建 IOC 表：

| 类型 | 值 | 描述 |
|------|-----|------|
| IP | 127.0.0.1 | 源地址（本地） |
| URI | /beacon?id=101 | 可能的 C2 信标 |
| UA | curl/8.0 | 使用的工具 |

### CHECK

- 完成 IOC 表了吗？
- 哪个端点看起来最可疑？为什么？
