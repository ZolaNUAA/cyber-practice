# Lab10：IDS 告警分析

## 学习目标

1. 理解 IDS 告警格式（Suricata Eve JSON）
2. 掌握使用 jq 进行告警数据的筛选、统计、分组
3. 建立告警分诊（Alert Triage）的优先级思维
4. 能够将 IDS 告警与实际攻击行为关联

## 预备知识

### IDS 发展历史

**1980 年代**：James Anderson 在《Computer Security Threat Monitoring and Surveillance》中首次提出入侵检测概念。

**1998 年**：Sourcefire 创始人 Martin Roesch 创建 **Snort**，成为最著名的开源网络 IDS。

**2009 年**：OISF（Open Information Security Foundation）创建 **Suricata**，多线程架构，性能更高，支持 Eve JSON 日志格式（本实验使用）。

**告警疲劳（Alert Fatigue）**：
- 大型企业 IDS 每天产生 **数十万条** 告警
- 研究显示约 **80%** 是误报
- 安全分析师必须在海量噪声中找到真实攻击

### Suricata Eve JSON 格式

```json
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
