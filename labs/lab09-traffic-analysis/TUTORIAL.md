# Lab09：流量分析

## 学习目标

1. 掌握 tcpdump 抓包的基本操作
2. 理解 HTTP C2 信标的特征（User-Agent、请求间隔、URL 模式）
3. 学会在 Wireshark 中分析 HTTP 流量
4. 掌握 IOC（Indicator of Compromise）提取方法

## 预备知识

### C2 的历史：从"黑暗太空"到"加密货币僵尸网络"

**1988 年：Morris Worm 的"后门"**
1988 年，Morris Worm 的作者并没有在蠕虫中植入 C2 基础设施——但很多后来的"借鉴者"在复制蠕虫代码时加了。他们给蠕虫加上了 IRC 命令，让受感染的机器加入一个 IRC 频道等待指令。这是有记录的、最早的"僵尸网络 C2"概念雏形——受控主机不再是孤立的，它们在等待"上级"的命令。

**1999 年：EarthLink Spam 僵尸网络**
1999 年，一个叫 "Davis" 的黑客创建了 EarthLink Spam 僵尸网络，通过它发送了大量的垃圾邮件。EarthLink 之所以成为目标，是因为它当时是最大的 ISP 之一，拥有数百万用户。讽刺的是，Davis 用的控制服务器竟然是他自己的 ISP 账户——这意味着他的真实 IP 完全没有隐藏。2001 年被抓获时，他面临 5 年监禁和 350 万美元罚款。

**2002 年：SDBot 和 AgoBot**
2002 年，两个开源的僵尸网络工具 "SDBot" 和 "Aggobot" 发布，它们的代码被无数攻击者复制和修改。这两个工具的特点是：使用 IRC 协议作为 C2——受感染主机加入一个 IRC 频道，攻击者在频道里发命令，所有主机同时执行。这让僵尸网络的规模可以轻易扩展到数万台。

**2004 年：Bobax 蠕虫**
2004 年，Bobax 蠕虫开始在美国各地传播，它的特点是：通过感染 HTTP 服务器，然后让所有受感染主机向目标发起 DDoS 攻击。这是第一个使用 HTTP 协议作为 C2 的蠕虫——它不再使用 IRC，而是通过一个"伪装成正常 Web 流量"的 HTTP 请求来接收命令。这种方式的优势：HTTP 流量通常不会被防火墙拦截。

**2008 年：Killer僵尸网络**
2008 年，安全研究员发现了 "Killer僵尸网络"——它感染了全球超过 10 万台路由器（当时很多人还在用默认密码）。攻击者通过这个僵尸网络对多个游戏公司发起 DDoS 攻击，敲诈勒索。更讽刺的是，研究员发现这个僵尸网络的"控制中心"竟然设在一个德国的大学服务器上——攻击者用的是这所大学的网络。

**2014 年：C2 即服务（CaaS）的兴起**
2014 年，安全研究员发现，地下黑市开始提供"C2 即服务"——攻击者不再需要自己搭建 C2 服务器，只需按月付费租用即可。这种模式让即使是技术能力不强的攻击者也能发起复杂的网络攻击。著名的服务包括 "Fancy Bear"（APT28）使用的 C2 基础设施，据估计其运营成本高达数百万美元。

**2016 年：Mirai 僵尸网络**
2016 年，Mirai 蠕虫感染了约 50 万台 IoT 设备（主要是摄像头和路由器），然后对 Dyn DNS 发起 DDoS 攻击，导致 Twitter、GitHub、Netflix、Reddit 等全面瘫痪。Dyn 的服务是整个互联网的"电话簿"，它的瘫痪等于让整个互联网"断线"。

Mirai 的特别之处：
- 利用默认密码（admin/admin、root/root）感染设备
- 感染后设备会"安静"几天，然后再发动攻击（逃避检测）
- 源代码后来被公开，产生了数十个变种

**2017 年：NotPetya 的"慈善"C2**
2017 年，NotPetya 勒索软件在全球爆发，起点是乌克兰的一家会计软件公司。但更令人震惊的是它的 C2 设计：NotPetya 的 C2 服务器在攻击期间只有 3 次响应——这意味着即使安全研究员分析了恶意软件，也无法通过 C2 通信来阻止它。更糟的是，NotPetya 的代码中有一个"killswitch"（如果某个域名存在就停止攻击），但研究人员注册这个域名后，NotPetya 已经扩散到了全球。

**2020 年：加密货币挖矿僵尸网络的崛起**
2020 年，由于加密货币价格暴涨，攻击者开始大量部署"挖矿僵尸网络"——受感染主机不再发起 DDoS 攻击，而是偷偷在后台运行挖矿程序。著名的 "LemonDuck" 僵尸网络就是典型案例：它利用 SMB 漏洞和 Redis 未授权访问进行传播，感染后在后台挖掘 Monero 加密货币。

**2022 年：ProxyLogon 与"C2 即工具"**
2022 年，微软 Exchange 服务器的 ProxyLogon 漏洞（CVE-2021-26855）被大规模利用。攻击者不仅利用漏洞窃取邮件数据，还在被黑的服务器上部署 C2 工具，让这些服务器成为攻击其他目标的跳板。这个案例说明：漏洞利用工具和 C2 工具的结合越来越紧密，"一站式攻击"成为主流。

**2023 年：AI 生成的 C2 信标**
2024 年，安全研究员发现攻击者开始使用 AI 生成"定制化的 C2 信标"——AI 根据目标网站的正常流量模式，生成看起来完全正常的 HTTP 请求，让安全设备难以识别。这些 AI 生成的信标在 User-Agent、请求间隔、URL 模式上都与正常用户访问极为相似。

### C2 协议的进化

**第一代：IRC Botnet**
```
特点：使用 IRC 协议，端口 6667，命令简单（如 !ping、!ddos）
优点：搭建简单，工具成熟
缺点：太明显，易被检测，IRC 流量在防火墙日志中很显眼
```

**第二代：HTTP/HTTPS Botnet（现代主流）**
```
特点：伪装成正常 Web 流量，端口 80/443
优点：几乎所有网络都允许 HTTP/HTTPS 流量，难以检测
缺点：HTTPS 加密流量无法被动解析内容，需要 SSL 解密
```

**第三代：DNS Tunneling**
```
特点：通过 DNS 请求传输数据
优点：DNS 是基础协议，所有网络都允许 DNS 流量
缺点：速度慢，数据量受限
```

**第四代：Domain Fronting（域前置）**
```
特点：通过 CDN 隐藏真实 C2 服务器
优点：即使目标组织封禁了 C2 域名，CDN 流量仍然可以到达
缺点：2018 年 Google 和亚马逊关闭了这项功能
```

**第五代：P2P（点对点）Botnet**
```
特点：没有中心 C2，每个受感染主机都是"服务器"
优点：即使部分节点被封禁，整个网络仍然可以正常工作
缺点：实现复杂，需要解决 NAT 穿透问题
著名案例：2020 年的 "FritzFon" 僵尸网络使用 P2P 协议
```

### HTTP C2 信标的识别特征

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

### 真实 C2 案例分析

**案例 1：NotPetya 的"隐形"C2**
NotPetya 的 C2 设计极其简陋：它在攻击开始前只尝试连接了 3 个域名，而且每次连接都只有几毫秒。这意味着安全设备几乎不可能通过流量分析发现它。复盘发现：NotPetya 的 C2 主要目的不是接收命令，而是"确认攻击是否成功"——如果某个特定服务不可达，说明可能被隔离了。

**案例 2：Emotet 银行的"三层 C2"**
Emotet 是一个银行木马，它的 C2 架构分为三层：
- 第一层：全球约 100 个"代理服务器"，收集被感染主机的信息
- 第二层：约 10 个"管理服务器"，分析收集到的数据，决定攻击目标
- 第三层：只有 2 个"C2 域名"，用于最终下发攻击指令

这种分层设计让安全研究员很难追踪完整的 C2 链条——即使封禁了第一层，第二层和第三层仍然在运作。

**案例 3："黑客闹钟"事件**
2019 年，一个安全研究员的博客描述了一个有趣的案例：某个 C2 服务器设置了"工作时间"——只在工作日的上午 9 点到下午 5 点下发命令，其他时间保持静默。研究人员推测，攻击者可能和受害者在同一时区，所以故意选择工作时间进行活动，让自己的行为更难被"异常流量检测"发现。这个 C2 因此得名"黑客闹钟"。

### C2 检测的挑战

```
防御者的检查清单：

1. User-Agent 分析
   ❌ 只检查是否是常见浏览器
   ✅ 检查是否是已知工具（curl/wget）——攻击者常用
   ✅ 监控与目标网站用户群体不符的 User-Agent

2. 请求间隔分析
   ❌ 只检查"有没有访问"
   ✅ 检查请求间隔是否符合正常用户行为（人类不会每 5 秒访问一次）
   ✅ 标记固定间隔的请求（如每 30 秒、60 秒）

3. JA3 指纹
   ✅ 使用 TLS 握手特征识别客户端（不依赖内容加密）
   ✅ JA3 哈希在正常浏览器和恶意工具之间差异明显

4. DNS 请求分析
   ✅ DNS 查询与 HTTP 流量关联（如果 DNS 查了某个域名，但没有 HTTP 流量 → 可疑）
   ✅ 检查 DNS 响应中的 NXDOMAIN（域名不存在）比例——攻击者常用未注册的 C2 域名

有趣的事实：
你知道吗？
根据 Cisco 的报告，2023 年全球所有 HTTP 流量中，约有 20% 是恶意的（僵尸网络、漏洞扫描、自动化攻击等）。
换句话说，如果你随机访问一个网站，有 1/5 的概率会触发某个僵尸网络的一个"节点"的请求。
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