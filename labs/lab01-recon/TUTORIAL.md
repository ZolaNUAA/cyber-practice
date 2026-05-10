# Lab01：侦察与资产发现

## 学习目标

1. 掌握 nmap 端口扫描和服务识别
2. 理解 Web 服务器指纹采集方法
3. 学会构建资产表并评估风险等级
4. 了解侦察在网络攻击链中的地位

## 预备知识

### 什么是侦察（Reconnaissance）？

侦察是网络攻击生命周期的**第一个阶段**（Lockheed Martin Cyber Kill Chain 模型的第一步）。攻击者在这个阶段收集目标信息、识别入口点、建立攻击计划。

> 真实案例：2017 年 Equifax 数据泄露
> 攻击者通过公开渠道（Shodan、Censys）发现 Equifax 一台未修复 Apache Struts 漏洞的服务器，然后分三步完成：侦察 → 突破 → 数据窃取。1.47 亿用户数据泄露，起因是一个开放端口的指纹信息被识别。

### 为什么侦察至关重要？

```
攻击者视角：
在真实渗透测试中，侦察阶段通常占用 40%-60% 的时间。

原因：
1. 扫描 10% 的端口 → 可能发现 80% 的漏洞
2. 版本号 → 直接对应 CVE 编号 → 精确攻击
3. 指纹信息 → 缩小攻击工具选择范围

防御者视角：
"你无法保护你不知道存在的东西。"
—— 侦察阶段也是防守方发现暴露面的机会
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

**重要**：所有服务绑定在 `127.0.0.1`，不是真实网络，永远不会影响到外部。

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
