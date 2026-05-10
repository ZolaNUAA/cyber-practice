# TITLE: 发送流量 — 生成待分析的网络请求
# STEP: 3
# MINUTES: 8

### WHY

现在让流量经过我们抓包的目标——访问 traffic-lab 的不同端点。

### DO

1. 访问主页：
```
curl http://127.0.0.1:8089/
```

2. 访问 API 状态端点：
```
curl http://127.0.0.1:8089/api/status
```

3. 访问信标端点（模拟可疑通信）：
```
curl "http://127.0.0.1:8089/beacon?id=101"
```

4. 停止抓包：
```
sudo pkill tcpdump
```

5. 确认 PCAP 文件已生成：
```
ls -lh pcaps/lab09.pcap
```

### CHECK

- PCAP 文件是否生成且大于 0 字节？
- 你发送了哪些请求？
