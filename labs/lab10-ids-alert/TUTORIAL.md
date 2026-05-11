# Lab10：IDS 告警分析

## 学习目标

1. 理解 IDS 告警格式（Suricata Eve JSON）
2. 掌握使用 jq 进行告警数据的筛选、统计、分组
3. 建立告警分诊（Alert Triage）的优先级思维
4. 能够将 IDS 告警与实际攻击行为关联

## 预备知识

### IDS 的历史：从"审计日志"到"AI 驱动"

**1980 年：James Anderson 的开创性论文**
1980 年，James P. Anderson 在美国军方资助下，写了一篇名为《Computer Security Threat Monitoring and Surveillance》的论文。这是世界上第一篇系统性地讨论"入侵检测"的学术论文。Anderson 的核心观点是：与其试图阻止所有攻击（这在当时几乎不可能），不如建立一个"监控系统"，在攻击发生时或发生后及时发现它。但问题在于，这篇论文里没有给出任何实际的算法或系统——它只是概念性的"蓝图"。

**1986 年：Denning 的"入侵检测模型"**
1986 年，Dorothy E. Denning 在 SRI International（斯坦福研究所）发表了《An Intrusion Detection Model》，第一次提出了入侵检测的正式数学模型。她的方法基于两个假设：
1. 入侵行为与正常行为是可区分的
2. 入侵行为在统计上是可以被建模的

Denning 提出用"异常检测"（Anomaly Detection）的方法——先学习"正常"是什么样子，然后把所有偏离正常的行为标记为可疑。听起来很简单？但 1986 年的计算机几乎没有足够的计算能力来实现这个想法。Denning 的模型在 30 年后的人工智能时代才真正得到广泛应用。

**1988 年：第一次大规模安全事件推动 IDS 发展**
1988 年的 Morris Worm 事件让美国政府意识到：他们需要一套"自动化的入侵检测系统"。在此之前，安全监控几乎完全是人工的——管理员通过阅读日志文件来发现异常。但 Morris Worm 在 24 小时内感染了 6,000 台主机，没有任何自动化工具能够及时发现。结果：DARPA（美国国防高级研究计划局）资助了大量 IDS 研究项目，直接催生了 CIDF（Common Intrusion Detection Framework）和后来的 IDWG（Intrusion Detection Working Group）。

**1991 年：Network Associates 收购 Snort**
1991 年，Martin Roesch 还是一个大学生，他在研究一个项目时需要分析网络流量，于是自己写了一个小的网络嗅探工具。这个工具后来变成了 Snort——世界上最流行的开源 IDS。1998 年，Martin 创立了 Sourcefire（后来被 Cisco 收购）。Snort 的规则格式（"Snort rules"）至今仍是 IDS 领域的标准，几乎所有商业 IDS 产品都支持这种格式。

**1998 年：Cerberus 的"自动响应"争议**
1998 年，第一个商业 IDS 产品"IDES"（Intrusion Detection Expert System）的开发者发现：IDS 不仅仅可以检测攻击，还可以"自动响应"——比如封锁 IP、断开连接等。这引发了一场行业争议：自动响应是否应该被允许？支持者认为，人工响应太慢，攻击者可以在几秒内完成攻击；反对者认为，误报会导致正常用户被封锁，引发"自我拒绝服务"。最终，业界达成了共识：自动响应应该谨慎使用，只有在误报率极低的情况下才启用。

**2000 年：Narus 的"大数据"IDS**
2000 年，一家叫 Narus 的公司（后来被 Verizon 收购）开始处理"海量数据"的网络流量分析。他们的系统在 2001 年被用于分析 911 恐怖袭击前后的网络流量，帮助 FBI 追踪嫌疑人。Narus 的技术奠定了后来"网络态势感知"（Network Situational Awareness）的基础。

**2007 年：第一届 ICD（Intrusion Detection Conference）**
2007 年，第一届"入侵检测大会"（IEEE International Conference on Intelligence and Security Informatics）召开。这个会议汇集了来自学术界和企业界的安全研究者，推动了 IDS 技术的标准化和互通性。

**2009 年：Suricata 的诞生**
2009 年，OISF（Open Information Security Foundation）发布了 Suricata——一个全新的开源 IDS。Suricata 和 Snort 的核心区别：
- Snort 是单线程，Suricata 是多线程（性能更高）
- Suricata 原生支持 IPv6 和多线程分析
- Suricata 的日志格式是 Eve JSON（JSON 格式，易于解析）
- Suricata 支持 IP Reputation（IP 信誉库）

Suricata 的出现让 IDS 领域有了真正的"竞争"——这推动了 Snort 也开始改进自己的架构。

**2010 年：Zeek（Bro）的"网络分析框架"**
2010 年，Vern Paxson 把 "Bro"（一个网络协议分析器）重写并改名为 "Zeek"。Zeek 的理念与传统的 IDS 不同——它不是简单的"匹配规则"，而是一个"可编程的网络分析框架"。安全研究员可以用 Zeek 的脚本语言写任何复杂的分析逻辑。这种灵活性让 Zeek 成为了学术研究和企业安全运营的首选工具。到 2020 年，Zeek 项目正式改名为 "Zeek"（不再是 Bro）。

**2014 年：端点检测与响应（EDR）的崛起**
2014 年，安全领域出现了一个新概念：EDR（Endpoint Detection and Response）。传统的 IDS 是网络层面的（监控网络流量），EDR 是端点层面的（监控单个设备的行为）。两者的结合让安全团队能够"既看全局，又看细节"。著名产品包括 CrowdStrike 的 Falcon、Carbon Black 的 CB Response、SentinelOne 等。

**2017 年：机器学习进入 IDS**
2017 年，MIT CSAIL（计算机科学与人工智能实验室）发布了"AI2"系统——这是第一个使用机器学习自动检测零日攻击的 IDS。AI2 的工作方式是：先用无监督学习对网络流量进行聚类，然后让安全分析师对聚类结果进行标注（"这是攻击"、"这是正常"），再把这些标注反馈给机器学习模型，让它不断提高检测准确率。实验结果显示：AI2 可以检测出约 85% 的零日攻击，而传统的基于签名的 IDS 只能检测到约 50%。

**2020 年：SOAR 与自动化响应**
2020 年，SOAR（Security Orchestration, Automation and Response）平台开始普及。SOAR 可以与 IDS 联动：当 IDS 发现攻击时，SOAR 自动触发预定义的安全响应流程（如封锁 IP、隔离主机、发送告警等），无需人工介入。这大大提高了安全运营的效率。

**2023 年：AI 驱动的告警分类**
2023 年，CrowdStrike、SentinelOne 等公司的最新 IDS/EDR 产品开始使用"大型语言模型"（LLM）来自动分析告警。传统的 IDS 会产生大量误报，安全分析师需要在海量告警中找到真正的攻击。新的 AI 系统可以：
1. 自动总结每条告警的背景（"这个告警是什么攻击？"）
2. 评估告警的可信度（"这条告警有 80% 的概率是真实的攻击"）
3. 推荐下一步行动（"建议封锁这个 IP，然后进一步调查"）

**2024 年：加密流量分析与 ZTA**
2024 年，随着零信任架构（Zero Trust Architecture，ZTA）的普及，IDS 开始面临新的挑战：如何检测加密流量中的威胁？传统的做法是"SSL 解密"——在 IDS 处解密 HTTPS 流量后再检查。但随着隐私法规（GDPR、CCPA）的加强，这种做法变得越来越敏感。新的解决方案是"加密流量分析"（Encrypted Traffic Analysis，ETA）——不解密流量，而是通过机器学习分析加密流量的元数据（包大小、时间间隔、TLS 握手特征等）来识别威胁。

### 告警疲劳（Alert Fatigue）的心理学

```
你知道吗？

大型企业的安全运营中心（SOC）每天收到约 50 万条安全告警。

但安全分析师通常只能处理其中的 10%——剩下的 90% 被"忽略"了。

这就是"告警疲劳"：

1. 每次看到误报，分析师的"警觉性"会下降一点
2. 长期下来，分析师开始对所有告警"视而不见"
3. 当真正的攻击发生时，分析师可能已经"习惯性忽略"了

这就是为什么"告警质量"比"告警数量"更重要。

一个好的 IDS 规则应该是：
❌ "检测所有包含 'shell' 的 HTTP 请求"
✅ "检测所有从外部网络发起的、包含 'shell' 的、目标是内网服务器的 HTTP 请求"

思考题：
如果你的 IDS 每小时产生 1000 条告警，
但你的安全分析师每小时只能处理 100 条，
你会怎么办？
```

### IDS 的技术架构

```
┌─────────────────────────────────────────────────────────────┐
│                    IDS 架构                                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  流量采集 ──▶ 协议解析 ──▶ 规则匹配 ──▶ 告警生成 ──▶ 上报    │
│     │              │             │              │             │
│  tap/spAN      会话重组      签名匹配        告警分级         │
│  镜像流量      应用层解析     异常检测       实时告警         │
│                                                              │
└─────────────────────────────────────────────────────────────┘

IDS 的两种主要类型：

1. NIDS（Network-based IDS）
   - 监控网络流量
   - 部署在网络边界
   - 优点：可以看到整个网络的"全局视图"
   - 缺点：看不到加密流量的内容

2. HIDS（Host-based IDS）
   - 监控单个主机的行为（系统调用、日志文件、进程）
   - 部署在每台服务器上
   - 优点：可以看到主机的"内部"行为
   - 缺点：只能看到单台主机，无法关联全网
```

### 告警分诊（Alert Triage）的优先级

```
告警优先级（业界通行标准）：

P1（Critical，极高）：
- 成功利用的漏洞（如命令注入、RCE）
- 数据泄露迹象
- 横向移动
- 勒索软件行为

P2（High，高）：
- 高危漏洞的探测（如 SQL 注入尝试）
- 暴力破解成功
- 可疑的 C2 通信

P3（Medium，中）：
- 低危漏洞的探测
- 异常行为（但未确认是攻击）
- 违反安全策略（如访问禁止的网站）

P4（Low，低）：
- 可能的误报
- 信息性告警（如端口扫描）
- 变通行为（如使用非标准端口）

实际分诊时的问题：
- 误报率高（P3 中可能有 80% 是误报）
- 需要上下文（如源 IP 是否可信、目标是哪里）
- 需要关联分析（单个告警可能是误报，多个告警组合才是真实攻击）
```

### Suricata 规则示例与解析

```bash
# Suricata 规则示例

# 规则 1：检测命令注入
alert http any any -> $HOME_NET 8087 (
    msg:"LOCAL Command Injection Pattern";
    content:"host=";
    pcre:"/host=.*[;&|`$]/i";
    sid:1000001;
    rev:1;
)

# 规则 2：检测 SQL 注入
alert http any any -> $HOME_NET any (
    msg:"SQL Injection Attempt";
    content:"' OR '1'='1";
    pcre:"/(\bor\b|and\b).*=.*['\"]/i";
    sid:1000002;
    rev:1;
)

# 规则解释：
# alert        → 告警（不是 drop、reject）
# http         → HTTP 协议
# any any      → 任何源 IP 和源端口
# ->           → 流向
# $HOME_NET    → 目标网络（变量，定义在 suricata.yaml）
# 8087         → 目标端口
# msg:         → 告警消息
# content:     → 要匹配的原始字节
# pcre:        → 正则表达式匹配
# sid:         → 规则 ID
# rev:         → 规则版本
```

### IDS 的未来趋势

```
1. AI 驱动的告警分析
   - LLM 自动总结告警上下文
   - 减少分析师的工作量
   - 但 AI 也有误判，需要人机配合

2. 加密流量分析（ETA）
   - 不解密，只分析元数据
   - TLS 握手特征、JA3 指纹、包大小分布
   - 隐私友好，不触碰加密内容

3. 云原生 IDS
   - Kubernetes 环境中的 IDS
   - 服务网格（Service Mesh）流量监控
   - 零信任网络的监控

4. 协同防御
   - IDS 与 threat intelligence 结合
   - 实时从外部情报源获取新规则
   - 跨组织的威胁情报共享（ISAC）
```

## 实验环境

```bash
./student.sh  # 选择对应的实验开始
```

**证据文件**：`evidence/ids/eve.json`

## 操作步骤

### 步骤 1：查看告警文件结构

```bash
# 首先确认文件存在
ls -lh evidence/ids/

# 查看文件内容（完整 JSON）
cat evidence/ids/eve.json

# 或者查看格式化后的 JSON
jq -s . evidence/ids/eve.json
```

**预期输出**（示例，`jq -s .` 会把多行 JSON 告警临时显示为数组）：
```json
[
  {
    "timestamp": "2026-05-10T10:02:31.000000+0800",
    "event_type": "alert",
    "src_ip": "127.0.0.1",
    "src_port": 51422,
    "dest_ip": "127.0.0.1",
    "dest_port": 8082,
    "proto": "TCP",
    "alert": {
      "signature": "LOCAL WEB Backup Directory Access",
      "category": "Attempted Information Leak",
      "severity": 2
    },
    "http": {
      "hostname": "127.0.0.1",
      "url": "/backup/db-backup.txt",
      "http_user_agent": "curl/8.0"
    }
  },
  {
    "timestamp": "2026-05-10T10:08:11.000000+0800",
    "event_type": "alert",
    "src_ip": "127.0.0.1",
    "src_port": 51430,
    "dest_ip": "127.0.0.1",
    "dest_port": 8087,
    "proto": "TCP",
    "alert": {
      "signature": "LOCAL Command Injection Pattern",
      "category": "Web Application Attack",
      "severity": 1
    },
    "http": {
      "hostname": "127.0.0.1",
      "url": "/?host=127.0.0.1%3Bid",
      "http_user_agent": "Mozilla/5.0"
    }
  }
]
```

### 步骤 2：告警统计与汇总

```bash
# 查看告警总数
jq -s 'length' evidence/ids/eve.json

# 按严重程度分组统计
jq -s -r '[.[] | .alert.severity] | group_by(.) | map({severity: .[0], count: length})' evidence/ids/eve.json

# 按告警类型分组
jq -s -r '[.[] | .alert.category] | group_by(.) | map({category: .[0], count: length})' evidence/ids/eve.json

# 按目标端口分组（确定被攻击的服务）
jq -s -r '[.[] | .dest_port] | group_by(.) | map({port: .[0], count: length})' evidence/ids/eve.json

# 按源 IP 分组（确定攻击来源）
jq -s -r '[.[] | .src_ip] | group_by(.) | map({ip: .[0], count: length})' evidence/ids/eve.json
```

**记录**：
```
告警总数：X 条
按严重程度：[列出分组]
按告警类型：[列出分组]
按目标端口：[列出分组]
按源 IP：[列出分组]
```

### 步骤 3：提取告警摘要表格

```bash
# 格式化输出为表格（时间、告警名称、严重程度、目标端口、URL）
jq -s -r '.[] | [.timestamp, .alert.signature, .alert.severity, .dest_port, .http.url] | @tsv' evidence/ids/eve.json

# 标记高严重程度的告警
jq -s -r '.[] | if .alert.severity <= 2 then "⚠️ HIGH: \(.alert.signature)" else "  LOW: \(.alert.signature)" end' evidence/ids/eve.json
```

**预期输出**：
```
timestamp                 signature                           severity  port  url
2026-05-10T10:02:31...    LOCAL WEB Backup Directory Access   2        8082  /backup/db-backup.txt
2026-05-10T10:08:11...    LOCAL Command Injection Pattern     1        8087  /?host=127.0.0.1%3Bid
```

### 步骤 4：告警优先级分析

基于分析结果，回答以下问题：

**问题 1**：哪条告警的严重程度最高？为什么？
**问题 2**：同一次攻击是否触发了多个告警？（例如，同一源 IP 访问不同端口）
**问题 3**：哪些告警可能是误报？（正常用户行为触发）

```bash
# 检查是否存在同一源 IP 的多次告警
jq -s 'group_by(.src_ip) | .[] | {ip: .[0].src_ip, count: length, alerts: [.[] | .alert.signature]}' evidence/ids/eve.json

# 检查是否有时间相近的连续告警（可能是攻击者在扫描）
jq -s -r '.[] | .timestamp' evidence/ids/eve.json
```

### 步骤 5：告警详情深度分析

```bash
# 查看特定告警的完整信息（-s 会把 NDJSON 多行告警临时读成数组）
jq -s '.[] | select(.alert.severity==1)' evidence/ids/eve.json

# 查找特定 URL 的告警
jq -s '.[] | select(.http.url | contains("beacon"))' evidence/ids/eve.json

# 查找特定类别的告警
jq -s '.[] | select(.alert.category == "Web Application Attack")' evidence/ids/eve.json

# 提取所有告警的完整 HTTP 信息
jq -s -r '.[] | "\(.timestamp) | \(.src_ip):\(.src_port) -> \(.dest_ip):\(.dest_port) | \(.http.url) | UA: \(.http.http_user_agent)"' evidence/ids/eve.json
```

### 步骤 6：撰写分析笔记

基于以上分析，撰写一份简短的分析师笔记：

```
【IDS 告警分析笔记】

告警总数：2 条
高优先级告警（severity <= 2）：2 条

告警 1：Backup Directory Access
- 时间：2026-05-10T10:02:31
- 源：127.0.0.1:51422
- 目标：127.0.0.1:8082
- URL：/backup/db-backup.txt
- 分析：攻击者访问了备份目录并下载了数据库备份文件
- 建议：立即审查 /backup/ 目录是否需要删除

告警 2：Command Injection Pattern
- 时间：2026-05-10T10:08:11
- 源：127.0.0.1:51430
- 目标：127.0.0.1:8087
- URL：/?host=127.0.0.1%3Bid（URL 解码：/?host=127.0.0.1&id）
- 分析：攻击者尝试在 host 参数中注入 ;id 命令分隔符
- 建议：检查 cmd-lab 服务是否有命令注入漏洞

关联分析：
- 两条告警来自同一源 IP（127.0.0.1），但目标端口不同
- 告警 1 在前（10:02），告警 2 在后（10:08）
- 攻击者可能是同一人，先发现备份目录（侦察），后尝试命令注入（利用）
```

## 技术原理

### Suricata 告警严重程度定义

```
Suricata severity 等级：
1 = Emergency（紧急）— 系统级紧急事件
2 = Alert（警报）— 需要立即关注
3 = Critical（严重）— 高危漏洞触发
4 = Error（错误）— 配置错误或异常
5 = Warning（警告）— 可疑但不确定
6 = Notice（通知）— 正常但值得注意的事件
7 = Info（信息）— 调试信息

本实验中的告警：
- severity 2 = Alert（信息泄露告警）
- severity 1 = Emergency（命令注入告警，极高危）
```

### 告警分诊流程图

```
收到新告警
     │
     ▼
严重程度 1-2？ ──是──▶ 立即调查（最高优先级）
     │
     否
     ▼
是否为已知误报模式？
     │
     ├──是──▶ 记录 → 更新过滤规则
     │
     否
     ▼
检查告警详情：
  - 源 IP 是否为内网？（内网横向移动）
  - URL 参数是否包含恶意模式？
  - User-Agent 是否异常？
     │
     ▼
关联分析：同一源 IP 的其他告警？
     │
     ├──有──▶ 可能是真实攻击，升级
     │
     └──无──▶ 单一告警，可能误报
```

### jq 高级用法

```bash
# 条件过滤
jq -s '.[] | select(.alert.severity > 2)' evidence/ids/eve.json  # 只看严重程度 > 2

# 聚合统计
jq -s '[.[].alert.signature] | group_by(.) | map({sig: .[0], count: length}) | sort_by(.count) | reverse' evidence/ids/eve.json

# 时间范围过滤
jq -s '.[] | select(.timestamp | startswith("2026-05-10T10"))' evidence/ids/eve.json

# 多字段排序
jq -s 'sort_by(.alert.severity, .timestamp)' evidence/ids/eve.json

# 输出为 CSV
jq -s -r '.[] | [.timestamp, .alert.signature, .alert.severity] | @csv' evidence/ids/eve.json
```

## 思考题

### 思考题 1：告警严重程度的实际意义

**问题**：
- `severity: 1` 的告警是否一定比 `severity: 2` 更重要？为什么？
- 如果你的 SOC 每天收到 50 万条告警，但分析师只能处理 100 条，你会如何选择要处理的告警？
- 是否有告警的严重程度设置不合理的情况？（高危漏洞但严重程度低，或反之）

### 思考题 2：IDS 误报的来源

**问题**：
- 正常用户行为可能触发哪些 IDS 告警？（至少 3 个场景）
- IDS 规则如果太严格（容易触发），会导致什么问题？
- IDS 规则如果太宽松（难以触发），会导致什么问题？
- 如何平衡 IDS 规则的敏感度和精确度？

### 思考题 3：User-Agent 分析的价值

**场景**：告警中的 User-Agent 有：
- `curl/8.0`
- `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36`
- `python-requests/2.28.0`
- `Wget/1.21.3`

**问题**：
1. 哪个 User-Agent 最可疑？为什么？
2. 如果所有告警都来自 `curl/8.0`，说明什么？（提示：正常浏览器几乎不会用 curl）
3. 攻击者是否可以伪造 User-Agent？伪造的目的是什么？

### 思考题 4：从告警到完整攻击链

**场景**：IDS 产生了以下告警序列：

```
10:02  Alert: 备份目录访问 (severity=2, port=8082, URL=/backup/db-backup.txt)
10:05  Alert: SQL 注入尝试 (severity=1, port=3000, URL=/rest/user/login)
10:08  Alert: 命令注入模式 (severity=1, port=8087, URL=/?host=127.0.0.1%3Bid)
```

**问题**：
1. 这些告警之间有什么关联？（时间、源 IP、攻击阶段）
2. 如果你是分析师，你的调查顺序是什么？为什么？
3. 在告警 1 中，攻击者似乎没有利用漏洞，只是"访问"了备份目录。你如何确定他们是否下载了内容？IDS 能告诉你这些吗？

## 交付物

1. **告警文件分析截图** — jq 输出展示告警统计结果
2. **告警摘要表** — 按时间/严重程度/目标端口分类的表格
3. **分析师笔记** — 每条告警的分析和处置建议
4. **告警关联分析** — 如果有多条告警，说明它们之间的关联
5. **检测规则建议** — 基于分析，提出新的 IDS 规则或过滤条件
6. **思考题答案**

## 工具速查

```bash
# jq 基础分析
jq -s . evidence/ids/eve.json                          # 格式化显示
jq -s 'length' evidence/ids/eve.json                  # 告警总数
jq -s -r '.[] | .alert.signature' evidence/ids/eve.json  # 所有告警名称
jq -s -r '.[] | [.timestamp, .alert.severity, .dest_port] | @tsv' evidence/ids/eve.json  # 表格输出

# 过滤分析
jq -s '.[] | select(.alert.severity <= 2)' evidence/ids/eve.json   # 高优先级
jq -s '.[] | select(.http.url | contains("backup"))' evidence/ids/eve.json  # 特定URL

# 统计
jq -s -r '[.[].alert.severity] | group_by(.) | map({sev: .[0], count: length})' evidence/ids/eve.json
jq -s -r '[.[].dest_port] | group_by(.) | map({port: .[0], count: length})' evidence/ids/eve.json

# 排序和限制
jq -s 'sort_by(.alert.severity) | .[:5]' evidence/ids/eve.json  # 前 5 条最严重
```
