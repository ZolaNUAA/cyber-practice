# Lab11：日志关联

## 学习目标

1. 理解多源日志关联分析的方法论
2. 掌握跨日志源的事件关联技术（时间对齐、IP 关联）
3. 能够构建完整的攻击时间线
4. 识别日志记录不完整导致的盲区

## 预备知识

### 日志关联的历史

**2013 年 Target 数据泄露事件**：
- 攻击者通过 HVAC 供应商的凭证进入 Target 网络
- 防火墙和 IDS 告警已经产生（被检测到），但没有及时关联
- 攻击者在内网横向移动，最终窃取 4000 万张信用卡信息
- **问题根源**：日志分散，事件没有关联分析

**SIEM（安全信息与事件管理）** 的价值：
- Splunk、ArcSight、Microsoft Sentinel 本质上是自动化日志关联引擎
- 解决"数据孤岛"问题，让不同来源的日志可以交叉分析

### 日志关联的方法论

```
1. 时间排序（Chronological Ordering）
   → 按时间轴排列所有事件，找到攻击先后顺序

2. 模式匹配（Pattern Matching）
   → 同一 IP 在多个日志源出现？→ 横向移动
   → 同一 User-Agent 在多个请求中重复？→ 自动化工具
   → 同一 Session ID 关联多个请求？→ 同一用户/攻击者

3. 异常值检测（Anomaly Detection）
   → 正常用户在白天活跃，凌晨 3 点有活动？→ 可疑
   → 正常用户每次访问 5-10 个页面，突然访问 500 个？→ 可疑

4. 因果链推断（Causality Chain）
   → 先有信息泄露（备份文件）→ 后有认证成功（SSH）→ 后有横向移动
   → 还原完整攻击链
```

## 实验环境

```bash
./student.sh  # 选择对应的实验开始
```

**日志源**：
- `logs/nginx/` — Nginx 访问日志
- `logs/traffic/` — Traffic Lab 应用日志
- `logs/incident/` — Incident Lab 应用日志（如果有）
- `evidence/logs/` — 预置的样本日志文件

## 操作步骤

### 步骤 1：确认所有日志源

```bash
# 查找所有可用的日志文件
find logs evidence/logs -type f -name "*.log" -o -name "*.txt" -o -name "*.json" 2>/dev/null

# 查看每个日志文件的大小和内容
for f in $(find logs evidence -type f 2>/dev/null | head -20); do
    echo "=== $f ==="
    head -5 "$f"
    echo ""
done
```

**你应该记录**：
```
日志目录结构：
├── logs/
│   ├── nginx/access.log
│   ├── traffic/traffic.log
│   └── incident/incident.log
├── evidence/logs/
│   └── [样本文件]

日志文件格式：
- nginx access.log：[时间] [IP] [方法] [路径] [状态码]
- traffic.log：[ISO时间] [IP] [事件] [UA]
- incident.log：[ISO时间] [IP] [事件]
```

### 步骤 2：生成跨日志源的流量

```bash
# 生成 Nginx 访问（模拟侦察）
curl -s http://127.0.0.1:8082/ > /dev/null
curl -s http://127.0.0.1:8082/backup/ > /dev/null
curl -s http://127.0.0.1:8082/backup/db-backup.txt > /dev/null

# 生成 Traffic Lab 流量（模拟 C2 信标）
curl -s "http://127.0.0.1:8089/" > /dev/null
curl -s "http://127.0.0.1:8089/api/status" > /dev/null
curl -s "http://127.0.0.1:8089/beacon?id=101" > /dev/null

# 等待几秒再发一次
sleep 3
curl -s "http://127.0.0.1:8089/beacon?id=102" > /dev/null

# 关闭所有容器（观察日志是否被持久化）
```

### 步骤 3：分析 Nginx 日志

```bash
# 查看 Nginx access log 的格式
cat logs/nginx/access.log | head -20
```

**Nginx access_log 格式**：
```
127.0.0.1 - - [10/May/2026:09:02:31 +0000] "GET /backup/db-backup.txt HTTP/1.1" 200 1543 "-" "curl/8.0"
格式：[IP] [时间] "[方法] [路径] [协议]" [状态码] [大小] "[Referer]" "[User-Agent]"
```

**分析要点**：
- 哪些请求访问了 `/backup/` 路径？
- 哪些请求返回了 404（可能是扫描）？
- 哪些 IP 在短时间内访问了大量路径？

```bash
# 提取访问备份目录的记录
grep "/backup/" logs/nginx/access.log

# 提取可疑的 404 请求
grep "404" logs/nginx/access.log

# 按 IP 统计访问量
awk '{print $1}' logs/nginx/access.log | sort | uniq -c | sort -rn
```

### 步骤 4：分析 Traffic Lab 日志

```bash
# 查看 Traffic Lab 日志格式
cat logs/traffic/traffic.log | head -20
```

**traffic.log 格式**：
```
2026-05-10T09:05:12.123456Z 127.0.0.1 normal_index ua=Mozilla/5.0...
2026-05-10T09:05:15.234567Z 127.0.0.1 api_status ua=curl/8.0
2026-05-10T09:05:20.345678Z 127.0.0.1 suspicious_beacon id=101 ua=curl/8.0
```

**分析要点**：
- 哪些事件标记为 `suspicious_beacon`？
- 信标的 id 参数有什么规律？
- User-Agent 是否与正常浏览器一致？

```bash
# 提取 beacon 请求
grep "beacon" logs/traffic/traffic.log

# 提取可疑事件
grep "suspicious" logs/traffic/traffic.log

# 按事件类型统计
awk '{print $4}' logs/traffic/traffic.log | sort | uniq -c
```

### 步骤 5：构建统一时间线

基于两个日志源，构建时间线：

```bash
# 时间范围：查找所有事件的时间跨度
echo "=== Nginx 事件时间范围 ==="
head -1 logs/nginx/access.log | awk '{print $4}' | tr -d '[]'
tail -1 logs/nginx/access.log | awk '{print $4}' | tr -d '[]'

echo "=== Traffic 事件时间范围 ==="
head -1 logs/traffic/traffic.log | awk '{print $1}'
tail -1 logs/traffic/traffic.log | awk '{print $1}'
```

**时间线构建**（手动整理）：

| 时间 | 来源 | 事件 | 详情 |
|------|------|------|------|
| 09:02:31 | Nginx | GET /backup/db-backup.txt | 200, curl/8.0 |
| 09:05:12 | Traffic | normal_index | 访问首页 |
| 09:05:15 | Traffic | api_status | 访问 API |
| 09:05:20 | Traffic | **suspicious_beacon id=101** | ⚠️ C2 信标 |
| 09:05:23 | Traffic | **suspicious_beacon id=102** | ⚠️ C2 信标 |

### 步骤 6：关联分析

**问题 1**：Nginx 和 Traffic 的事件是否来自同一 IP？
```bash
# Nginx 中的源 IP
awk '{print $1}' logs/nginx/access.log | sort -u

# Traffic 中的源 IP
awk '{print $3}' logs/traffic/traffic.log | sort -u
```

**问题 2**：如果 IP 相同，说明什么？（可能是同一攻击者在侦察不同服务）

**问题 3**：如果 Nginx 日志中出现 `/backup/db-backup.txt` 访问，而 Traffic 日志中出现了信标，两者有时间关联吗？

```bash
# 尝试关联：在同一时间段内（2分钟内）两个服务是否都有活动
# 先找到 Nginx 访问备份文件的时间
grep "db-backup" logs/nginx/access.log

# 再找 Traffic 在该时间附近的活动
# 人工对比或写脚本关联
```

## 技术原理

### 日志格式差异与统一

```
Nginx access_log：
127.0.0.1 - - [10/May/2026:09:02:31 +0000] "GET /path HTTP/1.1" 200 123 "-" "UA"

SSH auth log（/var/log/auth.log）：
May 10 09:05:12 ssh-lab sshd[123]: Accepted password for student from 127.0.0.1

Traffic log（JSON）：
{"timestamp":"2026-05-10T09:05:12Z","event":"beacon",...}

时间格式不统一：
- Nginx：[10/May/2026:09:02:31 +0000]
- SSH：May 10 09:05:12
- Traffic：2026-05-10T09:05:12Z

→ 需要统一转换为 ISO 8601 格式才能做时间关联
```

### 常见日志盲区

```
┌──────────────────────────────────────────────────────────┐
│              典型日志盲区（Logging Gaps）                  │
├──────────────────────────────────────────────────────────┤
│ ❌ 无 WebSocket 记录 → 信标通信可能完全看不到              │
│ ❌ DNS 查询未记录 → DNS Tunneling 无法追踪               │
│ ❌ 加密流量无解密 → HTTPS C2 无法分析内容                  │
│ ❌ 容器内部日志未持久化 → 容器重启后丢失                   │
│ ❌ 内存中的恶意进程 → 不落盘，无文件日志                    │
│ ❌ 已删除的文件操作 → 日志被清除，溯源困难                  │
└──────────────────────────────────────────────────────────┘

真实案例：
2015 年 某公司服务器被入侵，攻击者使用 tmpfs（内存文件系统）
存储工具和日志，服务器重启后所有痕迹消失。
防御措施：监控 /proc 环境或使用 syslog 将日志实时传输到远程服务器
```

### 日志完整性检查

```bash
# 检查日志文件是否被截断或删除
ls -la logs/nginx/access.log
# 如果 modification time 异常早或 inode 变化，可能是被清除

# 检查日志轮转配置
cat /etc/logrotate.d/nginx

# 检查 Docker 日志配置
docker inspect nginx-lab | grep -i log
```

## 思考题

### 思考题 1：时区不同步的日志关联

**场景**：
- Nginx 日志：`[10/May/2026:09:02:31 +0000]`（UTC）
- Traffic 日志：`2026-05-10T09:02:31Z`（UTC）
- SSH 日志：`May 10 17:02:31`（+0800 CST，本地时间）

**问题**：
1. 如果你把所有日志直接按字符串排序，SSH 的 17:02 会排在 Nginx 的 09:02 之后，但这实际上是错误的顺序（17:02 是晚上，应该是之后的事件）。为什么？
2. 如何正确地将不同格式的时间转换为可排序的格式？（给出具体方法）
3. 如果日志中没有时区信息（如 `May 10 09:02:31` 没有标注时区），你如何确定它是哪个时区？

### 思考题 2：日志关联在 APT 检测中的作用

**APT（高级持续性威胁）** 的特点：
- 低慢攻击（Low and Slow）：攻击者在网络中潜伏数月，动静很小
- 内网横向移动：通过多个跳板机，IP 不断变化
- 凭据重用：使用窃取的凭据在多台机器间移动

**问题**：
1. 在 APT 场景下，如果攻击者每台机器只活动几分钟就切换，单纯看单台机器的日志能发现吗？
2. SIEM 如何通过日志关联发现 APT？（提示：考虑"异常行为模式"而非"单个告警"）
3. 如果攻击者使用 VPN 变换 IP，但 Cookie/Session 不变，日志关联如何追踪？

### 思考题 3：日志太多 vs. 日志太少

**问题**：
1. 如果一个 SOC 每天收到 500GB 日志，SIEM 存储和分析能力都达到瓶颈。你会采取什么措施？
2. 如果日志太少（如只记录 HTTP 状态码，不记录 User-Agent 和 Referer），会漏掉哪些攻击的检测？
3. 如何在"存储成本"和"安全可见性"之间找到平衡点？（提示：日志分级、采样、告警驱动的深度记录）

### 思考题 4：日志完整性的信任问题

**场景**：服务器被入侵后，攻击者删除了 `auth.log` 并创建了一个新的空文件。

**问题**：
1. 如何发现日志文件被人为修改过？（提示：考虑 inode、时间戳、校验和）
2. 如果日志被修改，分析师会看到什么假象？
3. 如何确保日志的不可否认性（Non-repudiation）？（提示：WORM 存储、数字签名、syslog 远程转发）

## 交付物

1. **日志目录结构报告** — 所有日志源及其格式说明
2. **跨日志源时间线** — 整合 Nginx、Traffic 等日志的事件时间线
3. **关联分析报告** — 指出哪些事件可能是同一攻击者发起的
4. **异常发现** — 从日志中发现的任何可疑活动
5. **日志盲区分析** — 哪些攻击可能无法被当前日志检测到
6. **思考题答案**

## 工具速查

```bash
# 查看所有日志文件
find logs evidence -type f | xargs ls -la

# Nginx 日志分析
grep "/backup/" logs/nginx/access.log
awk '{print $7}' logs/nginx/access.log | sort | uniq -c | sort -rn | head -10

# Traffic 日志分析
grep "beacon" logs/traffic/traffic.log
grep "suspicious" logs/traffic/traffic.log

# 时间格式转换（awk）
# 将 Nginx 日志时间转换为 ISO 格式
awk '{gsub(/\[|\]/,""); gsub(/\//,"-"); print}' logs/nginx/access.log

# 跨日志源关联（手动方法）
# 1. 提取每个日志源的时间戳和关键字段
# 2. 按时间排序
# 3. 识别同一 IP/用户的跨日志事件
```