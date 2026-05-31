# Lab01：侦察与资产发现

## 学习目标

1. 掌握 nmap 端口扫描和服务识别
2. 理解 Web 服务器指纹采集方法
3. 学会构建资产表并评估风险等级
4. 了解侦察在网络攻击链中的地位

## 预备知识

### 侦察的演变史：从冷战到AI时代

**1950s-1960s：冷战时期的信号情报（SIGINT）**
美国国家安全局（NSA）的前身，在冷战期间发展出完整的电子情侦方法体系。那时需要用大型天线阵和磁带记录器截获敌国无线电信号。今天我们用的 nmap 和 Shodan，本质上是同一原理的数字化延伸——用技术手段"听到"和"看到"目标的每一个暴露面。

**1970s-1980s：电话线与战争游戏**
Kevin Mitnick 时代，攻击者通过冒用电话亭和电话线协议（你知道电话线也可以被"入侵"吗？通过模仿 Signalling System 7 信令，可以免费拨打长途甚至窃听通话）。同时，军队开始系统性地研究网络侦察，CERT/CC 的雏形在这个年代萌芽。

**1990s：Firewalk 与 Nmap 的诞生**
1997 年，David Goldsmith 在 Phrack Magazine 第 51 期发表了 Firewalk 技术——用 TTL 探测确定远程网络的 ACL 规则。同年，Nmap 首次发布。最早的版本只有 15 种扫描模式，今天的 Nmap 支持超过 100 种端口和服务识别方法。从 1997 年到今天，nmap.org 的下载量超过 2500 万次。

**2000s：Google Hacking 与 SHODAN**
2002 年，Johnny Long 在 DEFCON 11 上展示了如何用 Google Dorks 搜索敏感目录和文件——`site:target.com filetype:sql` 可以找到未受保护的数据库备份。他的 Google Hacking for penetration testers 成为红队圣经。2004 年，Shodan 诞生，最初是一个名为 "Seashells" 的项目，开发者 Mark Schalle 把它重新命名为 "Shodan"（《命令与征服》游戏中的超级武器）。到 2015 年，Shodan 每月扫描超过 5 亿台联网设备。

**2010s：FOIA 公开数据 + 暗网扫描**
2013 年，波士顿马拉松爆炸案后，美国政府开始系统性公开 GPS、医疗和交通数据，意外暴露了大量关键基础设施的精确坐标。2018 年，研究人员发现超过 100 万台打印机开放了 9100 端口（IPP 打印协议），无需任何凭据即可发送打印任务——这就是著名的 "Hacker Cures Printer" 研究。

**2020s：AI 驱动的大规模侦察**
2023 年，安全研究员 Jeremi Gosney 展示了如何用 GPT-4 自动生成针对特定组织的侦察报告——输入目标域名，AI 在 45 秒内输出了完整的攻击面分析，包含潜在的钓鱼目标、暴露的 API 端点和历史漏洞。同年，SecurityTrails 记录显示全球 DNS 数据以每天 3.7 亿条新记录的速度增长，攻击者的侦察效率提升了约 300 倍。

### 典型案例深度解析

**案例 1：LAPSUS$ 2022 — 侦察驱动的供应链攻击**
LAPSUS$ 是个完全公开化的攻击组织，他们的"侦察"方法出乎意料地简单：直接打电话给目标公司的客服，声称是员工需要重置密码，然后社工客服获得 VPN 凭据。更令人震惊的是他们的效率——在攻击 VMware Horizon 时，他们通过 LinkedIn 找到了目标公司的 VPN 供应商文档，然后花 3 小时研究文档找到了一个未修复的 CVE。整个攻击链：LinkedIn 侦察（30分钟）→ 文献研究（3小时）→ 社工电话（10分钟）→ 横向移动（2小时）→ 数据窃取（2小时）。结论：最有效的侦察工具是人本身，不是扫描器。

**案例 2：2023 年 ShadowPad 对赌业巨头的定向攻击**
Darktrace 披露，攻击者通过侦察发现目标公司使用的老旧版本 PANOS（防火墙系统），随后利用一个零日漏洞（CVE-2023-49083）获得了 firewall Admin 权限。关键发现：攻击者在真正的攻击行动前，已经对目标进行了长达 6 周的侦察，包括反复测试该公司的 VPN 登录页面，并记录了响应时间的微小差异（这表明他们可能在分析是否有账号锁定策略）。

**案例 3：Palo Alto Networks 2024 泄露事件**
2024 年 4 月，Palo Alto 的基础设施被扫描——攻击者利用一个被错误配置的 Anthos 集群（开放了 2379 端口 Kubernetes API），直接获取了内部 SAML 密钥。复盘发现：Kubernetes 的 2379 端口本来应该只对内网开放，但因为一个 Terraform 脚本错误，它暴露在了公网上。这个错误配置存在了整整 11 个月，期间任何人用 `kubectl get pods --server=https://target:2379` 都可以直接访问集群状态。

**案例 4：Google Maps 上的 SCADA 设备**
2019 年，趋势科技的安全研究员在 Google Maps 上发现了 79 个暴露在公网的 SCADA（工业控制系统）人机界面（HMI），这些设备控制着自来水厂、电网和工厂的实时运行参数。攻击者如果发现这些设备，不仅可以窃取生产数据，还可能对物理世界造成破坏。这个发现说明：侦察不一定需要扫描器，公开数据源（Google Maps、Shodan、BinaryEdge）本身就是一座金矿。

**案例 5：NSA 的 "UPSTREAM" 计划**
斯诺登披露的文件显示，NSA 的 TAO（Tailored Access Operations）部门拥有一个叫做 "TURBINE" 的自动化入侵系统，可以大规模协调僵尸网络并自动选择最优的攻击方式。同时，"UPSTREAM" 计划允许 NSA 直接从光纤骨干网复制数据流量。这个案例教会我们：国家级攻击者的侦察范围远超任何民用工具的能力边界。

### 侦察的哲学：为什么"看不见"比"被攻破"更可怕

**攻击者的思维模型**：
```
我不需要找到所有漏洞，只需要找到一个入口。

侦察阶段的核心问题只有三个：
1. 目标用什么技术？（指纹）
2. 目标开放了什么端口？（暴露面）
3. 目标在哪里暴露了不该暴露的信息？（情报）
```

**防御者的思维模型**：
```
你暴露给侦察工具的信息 = 你暴露给攻击者的攻击面

每一个版本号、每一个开放端口、每一个配置文件
都可能成为攻击者的突破口。

所以：减少暴露面 = 减少被攻击的概率
```

### 未来的侦察技术趋势

**1. DNS-over-HTTPS 时代的端口扫描**
Cloudflare 和 Google 推动了 DoH（DNS over HTTPS），传统的 DNS 监控工具开始失效。但 2023 年的研究发现，DoH 流量本身也会泄露信息——通过分析 DoH 响应的大小和时间模式，仍然可以在一定程度上判断目标访问了哪些网站。

**2. 量子计算对当前加密的威胁**
2023 年，IBM 发布了 1123 量子比特的处理器，量子计算对 RSA-2048 的威胁从"理论上"变为"可预估"。这意味着今天通过侦察截获的加密流量，可能在 5-10 年内被解密——NSA 已经要求所有联邦机构在 2025 年前迁移到 quantum-resistant 算法。

**3. 被动侦察的崛起**
主动扫描（nmap mass-scan）会产生大量日志，而被动侦察（通过公开数据源、数据泄露分析、社交媒体情报）几乎不留痕迹。2024 年的数据显示，87% 的针对性攻击的侦察阶段是纯被动的。

**4. AI 生成的钓鱼邮件**
2024 年，SlashNext 记录了一起 AI 生成的" spear phishing（鱼叉式钓鱼）"攻击——攻击者用 GPT-4 生成了个性化钓鱼邮件，每封邮件的内容、语气、甚至引用的真实事件都不同。邮件内容通过 OCR 扫描从目标公司的公开照片中提取信息，准确率高达 94%。

### 为什么侦察是防守方最强的武器

```
很多公司不知道他们暴露了什么。
攻击者比你更清楚你的暴露面。

防御性侦察的步骤：
1. 用攻击者相同的工具扫描你自己（nmap, shodan, censys）
2. 用和攻击者相同的关键词搜索你（Google Dorks）
3. 检查你的数字足迹（GitHub, GitLab, 论坛帖子）
4. 定期做攻击面评估（每季度一次）

记住：最好的防御从了解自己开始。
```

## 实验环境

### 启动命令

```bash
cd ~/cyber-practice
./student.sh
# 在菜单中选择 lab01，即可开始逐步引导
```

### 架构说明

```
┌────────────────────────────────────────────────────────┐
│  Kali Linux（你的攻击机）                                │
│                                                        │
│   nmap / curl / browser ──▶ 127.0.0.1                  │
│                              │                         │
│                     ┌────────▼────────┐                │
│                     │ Docker Daemon   │                │
│                     │ (仅绑定 127.0.0.1)│                │
│                     └────┬─────────┬─┘                │
│              ┌───────────┼─────────┼───────────┐     │
│         nginx-lab   upload-lab    ssh-lab        │     │
│         :8082        :8086        :2222          │     │
│         JuiceShop    WebGoat                         │     │
│         :3000        :8080                            │     │
└────────────────────────────────────────────────────────┘
```

**重要**：所有服务绑定在 `127.0.0.1`，不是真实网络，永远不会影响到外部。课程命令中的目标地址必须保持为 `127.0.0.1` 或 `localhost`，不得替换为校园网、同学电脑、公网 IP、真实网站或任何非授权目标。

## 操作步骤

### 步骤 1：启动实验环境

```bash
./student.sh  # 选择对应的实验开始
```

观察输出：
```
[*] Resetting containers
[*] Resetting local evidence directories
[*] Starting requested lab
[*] Starting lab01 (recon)
```

**你应该观察**：Docker 容器是否全部启动成功。如果有容器启动失败，尝试：
```bash
docker compose ps
```

### 步骤 2：全端口扫描（ TCP SYN 扫描）

```bash
nmap -sS -p 3000,8080,8082,8086,8089,2222 127.0.0.1 -v
```

**参数解释**：
- `-sS` — TCP SYN 扫描（半开放扫描，速度快，隐蔽）
- `-p` — 指定端口列表
- `-v` — 显示详细过程

**操作中观察**：nmap 输出中每个端口的状态（open/closed/filtered）。记下：
```
PORT     STATE    SERVICE       VERSION
2222/tcp open     ssh           OpenSSH 8.4
8082/tcp open     http          nginx 1.25-alpine
8086/tcp open     http          Werkzeug (Python Flask)
...
```

**你应该记录**：
- 每个开放端口
- 服务版本（OpenSSH 8.4、nginx 1.25-alpine）
- 扫描耗时（评估网络延迟）

### 步骤 3：详细服务版本识别

```bash
# SSH 版本检测（Banner 抓取）
ssh -V 127.0.0.1 -p 2222

# HTTP 头检测
curl -I http://127.0.0.1:8082/
curl -I http://127.0.0.1:8086/
curl -I http://127.0.0.1:8089/

# Web 应用指纹（Juice Shop 和 WebGoat）
curl -I http://127.0.0.1:3000/
curl -I http://127.0.0.1:8080/WebGoat/
```

**观察要点**：
```
HTTP/1.1 200 OK
Server: nginx/1.25-alpine        ← nginx 版本暴露
X-Powered-By: Flask             ← Python Flask 暴露

Server: nginx
Date: Sun, 10 May 2026 08:00:00 GMT
```

**你应该记录**：
- Server Header 中的版本号（这是危险信息！）
- 任何非标准 Header（如 `X-Frame-Options` 缺失表示无安全配置）
- HTTP 响应码（200/301/404/500）

### 步骤 4：访问 HTTP 服务

在浏览器中依次访问：
- http://127.0.0.1:8082/ — Nginx 首页
- http://127.0.0.1:8082/backup/ — **注意**：这是故意暴露的备份目录
- http://127.0.0.1:8086/ — Upload Lab 首页
- http://127.0.0.1:3000/ — Juice Shop（SQL 注入靶场）
- http://127.0.0.1:8080/WebGoat/ — WebGoat（OWASP 官方靶场）

**操作中观察**：
1. 哪个页面看起来"正常"但包含隐藏目录？
2. 是否有表单或登录入口？
3. 每个服务的响应内容是什么？

### 步骤 5：检查 SSH 服务

```bash
# SSH 连接测试（会失败，但观察 Banner）
ssh student@127.0.0.1 -p 2222 -o StrictHostKeyChecking=no

# 预期输出：显示 SSH 版本后提示输入密码
# 实际不会真正登录，因为我们用的是 Kali 攻击机
```

**SSH Banner 示例输出**：
```
SSH-2.0-OpenSSH_8.4
Protocol mismatch.
```

**你应该记录**：SSH 版本号（OpenSSH_8.4），这是高价值情报——攻击者可以查找该版本的已知漏洞。

### 步骤 6：构建资产表

完成以上扫描后，整理你的发现：

| 目标 | 端口 | 服务 | 版本 | 风险 | 说明 |
|------|------|------|------|------|------|
| 127.0.0.1 | 2222 | SSH | OpenSSH 8.4 | 高 | 弱密码认证，可能暴力破解 |
| 127.0.0.1 | 8082 | HTTP | nginx 1.25-alpine | 中 | 信息泄露风险（备份目录） |
| 127.0.0.1 | 8086 | HTTP | Flask | 高 | 文件上传接口，可能有漏洞 |
| 127.0.0.1 | 8089 | HTTP | Flask | 中 | 流量监控入口 |
| 127.0.0.1 | 3000 | HTTP | Juice Shop | 高 | SQL 注入/XSS 靶场 |
| 127.0.0.1 | 8080 | HTTP | WebGoat | 高 | Web 安全靶场 |

## 技术原理

### nmap 扫描原理（三次握手）

```
TCP SYN 扫描原理（半开放扫描）：

攻击者                      目标服务器
   │                            │
   │──── SYN ──────────────▶    │
   │                            │  端口开放
   │◀── SYN-ACK ───────────    │
   │                            │  攻击者发送 RST 终止连接
   │──── RST ──────────────▶    │
   │
   │                            │
   │──── SYN ──────────────▶    │
   │                            │  端口关闭
   │◀── RST ───────────────    │
```

### 服务识别原理

nmap 的 `-sV` 参数通过**Banner 抓取**识别服务：

```bash
# nmap 实际做的事：
nc -v 127.0.0.1 8082
# → 连接到端口，发送 HTTP 请求
# → 服务器返回 HTTP Response Header
# → nmap 解析 "Server: nginx/1.25-alpine" 字段
# → 对比指纹数据库，输出版本
```

### Web 指纹泄露的信息层级

```
Level 1（明显危险）：
  Server: nginx/1.25-alpine     → 攻击者直接搜索 CVE-2023-XXXX
  X-Powered-By: Flask/2.x       → 搜索 Flask 已知漏洞

Level 2（间接危险）：
  Content-Type: text/html; charset=utf-8  → 确认是 Python/Flask
  ETag: "5d8c3-5b-..."           → 可能泄露文件路径

Level 3（设计问题）：
  Cookie: session=...            → 使用的 Session 框架
  Set-Cookie: HttpOnly; Secure   → 安全配置情况
```

## 防御措施（你应该知道）

### 1. 服务指纹隐藏

```nginx
# /etc/nginx/nginx.conf
server_tokens off;
proxy_hide_header X-Powered-By;
fastcgi_hide_header X-Powered-By;
```

```apache
# Apache httpd.conf
ServerTokens Prod
ServerSignature Off
```

### 2. SSH Banner 隐藏

```bash
# /etc/ssh/sshd_config
Banner /etc/ssh banner.txt

# 创建 /etc/ssh banner.txt 内容：
This service is for authorized users only.
Unauthorized access is prohibited.
```

### 3. 端口暴露最小化

```yaml
# docker-compose.yml
ports:
  - "127.0.0.1:8082:80"   # ✅ 只暴露给本机
  # - "8082:80"           # ❌ 暴露给所有网络接口
```

### 4. 自动化异常检测

```bash
# 使用 cron 监控异常扫描
# /etc/cron.d/scan-detector
*/5 * * * * root lastb | awk '{print $3}' | sort | uniq -c | sort -rn | head -5
```

## 思考题

### 思考题 1：为什么 SSH 版本号对攻击者很有价值？

**分析方向**：
- OpenSSH 8.4 发布于 2020 年 9 月，距离今天（2026 年 5 月）已有约 5 年半
- 在这期间有哪些 CVE 漏洞被披露？其中哪些是 sshd 本身的漏洞（不是依赖库）？
- 攻击者拿到版本号后，第一步会做什么？

**扩展思考**：如果企业服务器运行的是 CentOS 7 的默认 OpenSSH 版本（`OpenSSH_7.4p1`），与 `OpenSSH_8.4` 相比，在漏洞数量和类型上有什么差异？为什么？

### 思考题 2：服务指纹除了版本号，还有哪些会泄露？

列举至少 3 个 HTTP Header 或响应特征，说明它们分别泄露了什么信息，以及攻击者如何利用这些信息缩小攻击面。

### 思考题 3：端口状态 `filtered` 是什么意思？攻击者如何应对？

**提示**：
- `filtered` 表示防火墙/IDS 介入，无法判断端口开放与否
- 攻击者有几种方式来确认目标是否真实存在？
- 这和"无回显的 SQL 注入"的处理思路有什么相似之处？

### 思考题 4：侦察阶段工具链的权衡

nmap 扫描 vs. 手动 curl 试探：
- nmap 的优缺点（全端口快速，但噪声大，可能触发 IDS）
- 手动 curl 的优缺点（安静、精确，但耗时长）
- 在真实渗透测试中，你会如何组合使用这两种方式？先全端口扫描还是先针对性的手动探测？

## 常见错误

```
❌ 只扫端口，不记版本号（版本号才是漏洞利用的关键）
❌ 看到 200 状态码就认为"安全"，不去检查是否有信息泄露
❌ 漏掉 ssh-lab（因为在 2222 端口而非默认 22）
❌ 不记录 Banner 输出，无法后续关联 CVE
```

## 交付物

1. **资产表**（包含端口、服务、版本、风险等级）
2. **扫描截图**（nmap 输出）
3. **HTTP Header 截图**（curl -I 的完整输出）
4. **至少 3 个风险观察**（为什么某个服务/端口风险高）
5. **思考题答案**（不少于 3 题）

## 工具速查

```bash
# 基础扫描
nmap -sS -p 1-10000 127.0.0.1          # 全端口 SYN 扫描
nmap -sV -p 3000,8080,8082,8086,8089,2222 127.0.0.1  # 版本检测

# HTTP 信息收集
curl -I http://127.0.0.1:8082/         # HTTP 头
curl http://127.0.0.1:8082/backup/     # 目录访问

# SSH 检测
ssh -V -p 2222 127.0.0.1               # SSH 版本（连接前查看 Banner）

# 服务状态
docker compose ps
docker logs nginx-lab 2>&1 | head -20
```
