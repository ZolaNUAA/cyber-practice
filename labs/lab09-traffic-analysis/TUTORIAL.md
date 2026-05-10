# Lab09：流量分析

## 学习目标

1. 掌握 tcpdump 抓包的基本操作
2. 理解 HTTP C2 信标的特征（User-Agent、请求间隔、URL 模式）
3. 学会在 Wireshark 中分析 HTTP 流量
4. 掌握 IOC（Indicator of Compromise）提取方法

## 预备知识

### C2（命令与控制）通信概述

C2 是攻击链（Cyber Kill Chain）的第七阶段，攻击者通过 C2 控制已被入侵的主机。

**僵尸网络 C2 协议进化**：

```
第一代：IRC Botnet
  → 特征明显，易被检测（独特的 IRC 端口和命令）

第二代：HTTP/HTTPS Botnet（现代主流）
  → 伪装成正常 Web 流量，端口 80/443
  → 难以检测，因为 HTTPS 加密流量无法被动解析内容

第三代：DNS Tunneling
  → 通过 DNS 请求传输数据，绕过防火墙
  → 利用 DNS 协议的双向性（请求和响应）

第四代：Domain Fronting（域前置）
  → 通过 CDN 隐藏真实 C2 服务器
  → 利用 HTTPS 正常通信的域名
```

**真实案例**：2017 年 NotPetya 勒索软件通过 EternalBlue 传播，其 C2 通信在早期被错过，导致灾难性的全球传播。

### HTTP C2 信标特征

```
正常用户访问 Web 应用：
GET /api/status HTTP/1.1
Host: target.com
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8

C2 信标（攻击者控制僵尸网络）：
GET /beacon?id=101 HTTP/1.1
Host: evil-c2-server.com
User-Agent: Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0)
Accept: */*
Connection: Keep-Alive

C2 信标的识别特征：
1. User-Agent 与正常浏览器不符（版本老旧或完全伪造）
2. 请求路径异常（如 /beacon、/update、/checkin）
3. 请求间隔固定（每 60 秒、30 分钟等）
4. 参数结构不寻常（如 id=101，base64 编码的命令）
```

## 实验环境

```bash
./student.sh  # 选择对应的实验开始
```

**目标**：`http://127.0.0.1:8089`
**流量监控**：tcpdump on loopback interface

## 操作步骤

### 步骤 1：启动 tcpdump 抓包

```bash
# 创建 pcap 目录
mkdir -p pcaps

# 启动 tcpdump（后台运行）
# -i lo：抓取 loopback 接口（127.0.0.1）
# -w：保存为 pcap 文件
# tcp port 8089：只抓取目标端口的流量
sudo tcpdump -i lo -w pcaps/lab09.pcap tcp port 8089 &

# 记录 tcpdump 的 PID（后续用于停止）
TCPDUMP_PID=$!
echo "tcpdump PID: $TCPDUMP_PID"
```

**预期输出**：
```
tcpdump: listening on lo, link-type EN10MB (BSD), capture size 262144 bytes
```

**你应该记录**：
```
tcpdump PID: [PID 号码]
抓包接口: lo (loopback)
保存文件: pcaps/lab09.pcap
过滤条件: tcp port 8089
```

### 步骤 2：生成正常流量

等待约 5 秒后，执行正常请求：

```bash
# 等待 tcpdump 启动完成
sleep 2

# 生成正常流量
echo "=== 正常首页访问 ==="
curl -s http://127.0.0.1:8089/
echo ""

echo "=== 正常 API 调用 ==="
curl -s http://127.0.0.1:8089/api/status
echo ""

# 多发几次正常请求（模拟用户行为）
for i in {1..3}; do
    curl -s http://127.0.0.1:8089/ > /dev/null
    sleep 1
done

echo "正常流量生成完毕"
```

### 步骤 3：生成可疑 C2 信标流量

```bash
echo "=== 生成 C2 信标流量 ==="

# 信标请求 1：基本信标
curl -s "http://127.0.0.1:8089/beacon?id=101"
echo ""

# 信标请求 2：不同 ID
curl -s "http://127.0.0.1:8089/beacon?id=102"
echo ""

# 信标请求 3：伪装成其他字符串
curl -s "http://127.0.0.1:8089/beacon?id=malicious"
echo ""

# 信标请求 4：多次请求（模拟定期回连）
for i in {1..3}; do
    curl -s "http://127.0.0.1:8089/beacon?id=101" > /dev/null
    sleep 1
done

echo "C2 信标流量生成完毕"
```

### 步骤 4：停止 tcpdump 并检查捕获结果

```bash
# 停止 tcpdump
sudo kill $TCPDUMP_PID 2>/dev/null || sudo pkill tcpdump

# 等待一下让文件写入完成
sleep 1

# 检查 pcap 文件大小
ls -lh pcaps/lab09.pcap

# 确认捕获的包数量
sudo tcpdump -r pcaps/lab09.pcap -c 10 | head -20
```

**观察要点**：
- pcap 文件是否有内容（大小 > 0）？
- 包数量是否与请求次数匹配？
- 是否有任何异常（如大量重传）？

### 步骤 5：Wireshark 分析（基础）

```bash
# 使用 tshark（命令行版 Wireshark）分析
# 如果 Kali 没有 Wireshark GUI，使用 tshark

# 查看 HTTP 请求列表
sudo tshark -r pcaps/lab09.pcap -Y "http.request" -T fields \
  -e frame.time -e ip.src -e ip.dst \
  -e http.request.method -e http.request.uri \
  -e http.user_agent 2>/dev/null | head -30
```

**或使用 tcpdump 基础分析**：

```bash
# 查看所有 HTTP 请求
sudo tcpdump -r pcaps/lab09.pcap -n 'tcp port 8089' | grep "HTTP"

# 查看特定内容（如 beacon 路径）
sudo tcpdump -r pcaps/lab09.pcap -n 'tcp port 8089' | grep "beacon"
```

**你应该提取的信息**：

| 字段 | 值 | 备注 |
|------|-----|------|
| 源 IP | 127.0.0.1 | 攻击者（你的 Kali） |
| 目标 IP | 127.0.0.1 | 目标服务 |
| 请求方法 | GET | HTTP 方法 |
| 请求路径 | `/beacon?id=101` | 可疑信标路径 |
| User-Agent | curl/8.0 | 工具特征 |

### 步骤 6：构建 IOC 表

基于分析结果，构建指标表：

```bash
# 使用 tshark 提取完整的 HTTP 详情
sudo tshark -r pcaps/lab09.pcap -Y "http" -T fields \
  -e frame.number \
  -e frame.time_relative \
  -e ip.src \
  -e ip.dst \
  -e http.request.uri \
  -e http.user_agent \
  2>/dev/null
```

**分析结果示例**：

| # | 时间 | 源 IP | 请求 URI | User-Agent | 分析结论 |
|---|------|-------|---------|------------|---------|
| 1 | 0.000 | 127.0.0.1 | / | curl/8.0 | 正常请求 |
| 2 | 0.500 | 127.0.0.1 | /beacon?id=101 | curl/8.0 | ⚠️ **可疑信标** |
| 3 | 1.200 | 127.0.0.1 | /beacon?id=102 | curl/8.0 | ⚠️ **可疑信标** |
| 4 | 1.800 | 127.0.0.1 | /api/status | curl/8.0 | 正常请求 |

## 技术原理

### tcpdump 工作原理

```
tcpdump 是一个网络抓包工具，工作在链路层：
1. 设置网卡为混杂模式（promiscuous mode）
2. 捕获所有经过网卡的数据包
3. 应用 BPF（Berkeley Packet Filter）过滤规则
4. 将结果保存为 pcap 格式或输出到终端

BPF 语法示例：
tcp port 8089           → 只捕获 8089 端口的 TCP 包
tcp and port 8089       → 明确指定 TCP 和端口
tcp port 8089 and host 127.0.0.1  → 加上源/目标 IP 过滤
```

### HTTP 流量分析关键点

```
Wireshark/tshark 常用过滤器：

http.request.method == "GET"           → GET 请求
http.request.uri contains "beacon"    → URI 中含 beacon
http.user_agent == "curl/8.0"         → 特定 UA
http.response.code == 200              → 成功响应

帧级别分析：
frame.time_relative                    → 相对时间（秒）
frame.len                             → 包长度（大包可能是数据外泄）
tcp.stream                            → TCP 流编号（追踪完整会话）
```

### IOC 提取方法论

```
1. 时间排序（Chronological）
   → 按时间轴排列所有事件

2. 模式识别（Pattern Recognition）
   → 同一 IP 在多个日志中出现？→ 横向移动
   → 固定周期的请求？→ 自动化的 C2 信标
   → 异常的 User-Agent？→ 非浏览器客户端

3. 特征提取（Feature Extraction）
   → URI 模式（如 /beacon?id=XXX）
   → 请求头特征（如无 Accept-Language）
   → 响应大小（是否与正常响应一致）

4. 上下文关联（Context Correlation）
   → 同一会话内的多个请求是否有关联？
   → 信标 ID 是否与攻击者标识符对应？
```

## 思考题

### 思考题 1：HTTP C2 流量检测的难点

**问题**：在 HTTPS 加密流量中，以下信息是否仍然可见？
- 源 IP 和目标 IP
- 目标端口
- SNI（Server Name Indication，在 TLS Client Hello 中）
- 请求的 URL 路径（在 TLS 加密之后）

**扩展**：如果 C2 使用 HTTPS 并配合 Domain Fronting，检测难点在哪？

### 思考题 2：固定周期信标的优缺点

**问题**：攻击者为什么要让 C2 信标以固定周期（如每 60 秒）回连？
- 优点（对攻击者）：难以被检测、节省资源
- 缺点（对攻击者）：容易被 shodan/FOFA 等搜索引擎发现规律

**扩展**：攻击者如何改良这个问题？（提示：考虑抖动/Jitter、分批回连、协议伪装）

### 思考题 3：Wireshark 的局限性

**场景**：你抓了一个大 pcap 文件（1GB），Wireshark 打开卡死。

**问题**：
1. 除了 Wireshark，还有哪些工具可以分析大 pcap？（tshark、bro/zeek、tcpdump）
2. 如果 pcap 是在高吞吐量的链路上捕获的（10Gbps），完整分析可能需要什么硬件？
3. 如果攻击者使用了加密协议（如 HTTPS），Wireshark 能否看到明文内容？在什么情况下可以看到？

### 思考题 4：IOC 和 IOA 的区别

**问题**：
- IOC（Indicator of Compromise，妥协指标）：已知恶意活动的痕迹
- IOA（Indicator of Attack，攻击指标）：正在进行攻击的行为特征

**分析**：
1. `http://evil.com/beacon?id=101` 是 IOC 还是 IOA？
2. 在流量分析中，以下哪种更适合实时检测：C2 信标的静态特征（域名、URL 路径）还是行为特征（请求间隔、请求大小）？
3. 攻击者变换 C2 服务器域名时，防御者如何应对？

## 交付物

1. **pcap 文件** — `pcaps/lab09.pcap`（tcpdump 捕获结果）
2. **流量分析截图** — Wireshark/tshark 输出，展示信标流量
3. **IOC 表格** — 包含源 IP、目标 URL、User-Agent、时间间隔等
4. **正常 vs 可疑流量对比** — 说明哪些是正常流量、哪些是可疑信标
5. **检测规则说明** — 基于你的分析，提出检测规则（如 Wireshark 过滤表达式）
6. **思考题答案**

## 工具速查

```bash
# tcpdump 抓包
sudo tcpdump -i lo -w pcaps/lab09.pcap tcp port 8089    # 抓包保存
sudo tcpdump -r pcaps/lab09.pcap 'tcp port 8089'        # 读取分析
sudo tcpdump -r pcaps/lab09.pcap -n 'tcp port 8089' | grep beacon  # 过滤

# tshark（Wireshark 命令行）
sudo tshark -r pcaps/lab09.pcap -Y "http.request" -T fields -e http.request.uri -e http.user_agent

# 统计请求间隔
sudo tshark -r pcaps/lab09.pcap -Y "http.request" -T fields -e frame.time_relative -e http.request.uri

# curl 发送各种请求
curl http://127.0.0.1:8089/
curl "http://127.0.0.1:8089/beacon?id=101"
curl -A "Mozilla/4.0" "http://127.0.0.1:8089/beacon?id=malicious"

# 检查抓包文件
ls -lh pcaps/lab09.pcap
sudo tcpdump -r pcaps/lab09.pcap -c 10  # 前 10 个包
```