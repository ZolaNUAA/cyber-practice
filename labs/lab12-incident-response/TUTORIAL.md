# Lab12：事件响应

## 学习目标

1. 理解事件响应的完整生命周期（NIST SP 800-61）
2. 掌握从证据收集到报告撰写的完整流程
3. 能够基于日志和告警构建攻击时间线
4. 提出有效的遏制和长期加固方案

## 预备知识

### 事件响应的历史：从"灭火"到"风险管理"

**1988 年：Morris Worm 与 CERT 的诞生**
1988 年 11 月 2 日，Morris Worm 蠕虫感染了美国 Internet 上约 6,000 台计算机（当时 Internet 总共有约 60,000 台主机）。蠕虫的作者 Robert Morris Jr.（康奈尔大学的研究生）后来声称蠕虫的目的是"测试互联网的规模"——但这个"测试"导致了约 1000 万美元到 1 亿美元的损失（当时的币值）。

Morris Worm 事件后，美国国防高级研究计划局（DARPA）立即认识到：互联网需要一个"应急响应"机构。1988 年 11 月 14 日，CERT/CC（Computer Emergency Response Team Coordination Center）在卡内基梅隆大学成立。CERT/CC 的成立标志着"事件响应"作为一个独立学科的诞生。

但真正的问题是：当时的"事件响应"几乎是纯技术性的——服务器被黑了，技术人员去"修复"，然后继续运行。没有系统性的方法论，没有标准化流程，大多数公司甚至没有专门的安全团队。

**1990s：安全事件响应的"黑暗时代"**
1990 年代，企业安全事件被认为是"丢脸的事情"——公司不愿意公开承认自己被黑，也不愿意与同行共享信息。这导致了"安全孤岛"现象：同一个漏洞被攻击者利用了无数次，因为受害公司之间不共享情报。

1995 年，Kevin Mitnick 的案件让人们意识到"社会工程学"的危险性——Mitnick 通过假冒身份和电话钓鱼，入侵了数十家公司。但当时的"事件响应"计划几乎完全是技术性的，没有考虑到"人"的因素。

**1999 年：FIRST 的成立**
1996 年，来自 15 个国家的安全团队聚在一起，讨论如何协调跨国安全事件响应。1999 年，FIRST（Forum of Incident Response and Security Teams）正式成立。FIRST 的目标是为全世界的 CSIRT（Computer Security Incident Response Teams）提供一个协作平台。今天，FIRST 拥有来自 90 个国家的 500 多个成员组织。

**2001 年：Nimda 蠕虫与"多向量攻击"**
2001 年 9 月 18 日，Nimda 蠕虫爆发，它同时使用了 5 种不同的传播方式：
1. 邮件
2. Web 服务器漏洞
3. 文件共享
4. 后门程序
5. 攻击内部网络

Nimda 让安全界认识到：一个有效的安全事件必须考虑多个攻击向量，而不仅仅是单个漏洞。这也是后来"纵深防御"（Defense in Depth）理念的起源之一。

**2003 年：PCI DSS 与强制事件响应**
2004 年，支付卡行业安全标准委员会（PCI SSC）发布了 PCI DSS（Payment Card Industry Data Security Standard）1.0 版本。PCI DSS 第一次强制要求所有处理信用卡数据的公司必须：
- 建立安全事件响应流程
- 每年测试事件响应计划
- 在事件发生后 24 小时内报告

PCI DSS 是第一个把"事件响应"变成"合规要求"的标准化框架。

**2005 年：The Honeynet Project 与可视化分析**
2005 年，The Honeynet Project 发布了一系列工具，让安全分析师可以用可视化的方式"看到"攻击的全貌。这些工具包括：把日志转换成图形化时间线、自动构建攻击流程图、关联多个日志源的数据等。这些工具的核心理念是：事件响应不应该只是"找日志"，应该是"讲故事"——用图表和动画展示攻击者是如何一步一步入侵的。

**2007 年：NIST SP 800-61 的发布**
2008 年 1 月，NIST（美国国家标准与技术研究院）发布了 SP 800-61（Computer Security Incident Handling Guide）。这是世界上第一个正式的事件响应标准指南。SP 800-61 定义了：
1. 事件响应的四个阶段：准备、检测/分析、遏制/根除/恢复、事后回顾
2. 事件分类标准（病毒、蠕虫、未授权访问、拒绝服务等）
3. 事件严重性评估矩阵

SP 800-61 成为了全球各类 CSIRT 团队的标准参考文档。即使是 15 年后的今天，它的核心理念仍然完全适用。

**2010 年：Stuxnet——第一个国家级网络武器**
2010 年，Stuxnet 蠕虫被发现，它是世界上第一个"国家级网络武器"。Stuxnet 的目标是伊朗的核设施，它通过感染 U 盘穿越物理隔离网络，然后破坏离心机的控制系统的。Stuxnet 的事件响应揭示了一个新问题：国家级攻击者有无限的资源，可以花数年时间精心准备一次攻击。传统的"检测-响应"模式在面对这种对手时几乎失效。

**2013 年：Target 数据泄露与"供应链安全"**
2013 年 11 月，Target 的 POS 系统被植入恶意软件，4000 万张信用卡信息被盗。事件的起因是：一个 HVAC（暖通空调）供应商的远程管理账号被攻击者获得。这让整个安全行业开始关注"第三方风险"——你的安全不只是取决于你自己，还取决于你最弱的供应商。

**2014 年：Sony Pictures 事件与"数据销毁"**
2014 年 11 月，Sony Pictures 遭到"和平守护者"（Guardians of Peace）的攻击，所有数据被加密并被公开。FBI 正式指控朝鲜政府策划了这次攻击——这是历史上第一次有国家正式被指控对一家公司发动网络攻击。

**2015 年：OSINT 与"公开情报"**
2015 年，安全研究员开始大量使用 OSINT（Open Source Intelligence，公开来源情报）来进行事件响应。比如，通过 Twitter、LinkedIn、GitHub 等公开平台收集攻击者的信息。著名的 "Krebs on Security" 博客（由 Brian Krebs 运营）成为了安全事件报道的标杆。Brian Krebs 本人在 2016 年遭到了史上最大的 DDoS 攻击之一（Mirai 僵尸网络），峰值流量达到 665Gbps。

**2017 年：WannaCry 与"应急响应"**
2017 年 5 月 12 日，WannaCry 勒索软件在全球爆发，它利用了 NSA 泄露的 EternalBlue 漏洞（MS17-010）。WannaCry 在 24 小时内感染了 150 多个国家的数十万台计算机，包括英国 NHS（国家医疗服务体系）的数千台医疗设备。这次事件让人们认识到：漏洞的"补丁"速度远远跟不上漏洞被武器化的速度。

**2017 年：NotPetya——"无法恢复"的攻击**
2017 年 6 月，NotPetya 勒索软件爆发，它的破坏性远超预期：它不是"加密你的数据然后收赎金"，而是"彻底破坏你的数据"。即使你支付了赎金，数据也无法恢复。更糟糕的是，NotPetya 通过 PsExec 和 SMB 协议在内网快速传播，即使没有连接互联网的机器也可能被感染。

**2020 年：SolarWinds 供应链攻击**
2020 年 12 月，美国政府机构发现，多个联邦部门的网络被植入了"超新星"（Supernova）后门——这个后门是通过 SolarWinds 的软件更新分发的。攻击者（被认为是俄罗斯 SVR）在代码中潜伏了 9 个月才被发现。这是历史上已知的最复杂的供应链攻击之一。

**2021 年：Colonial Pipeline 事件与"关键基础设施"**
2021 年 5 月，美国最大的燃油管道运营商 Colonial Pipeline 遭到 DarkSide 勒索软件攻击，被迫关闭整个管道系统。这导致了美国东海岸的燃油短缺，多个州宣布进入紧急状态。Colonial Pipeline 支付了 440 万美元的赎金，但这次攻击让关键基础设施的网络安全成为了国家层面的议题。

**2022 年：Lapsus$ 组织的"社工攻击"**
2022 年，一个叫 Lapsus$ 的攻击组织让安全界认识到：最有效的攻击往往不是"技术漏洞"，而是"人"。Lapsus$ 的攻击手法包括：
- 给目标公司的客服打电话，声称是员工需要重置密码
- 用贿赂或威胁的方式，让 ISP 客服把目标的电话号码转移到自己的 SIM 卡上
- 直接买通目标公司的员工，让他们提供内部访问权限

有趣的是：Lapsus$ 的成员大多是青少年，他们不使用任何高级的黑客工具，只靠"社工"就能攻破任何人。

**2023 年：MOVEit 供应链攻击**
2023 年 5 月，Progress Software 的 MOVEit 文件传输软件被发现存在 SQL 注入漏洞。这个漏洞被 Clop 勒索软件组织利用，在接下来的一周内：
- 数千家企业的数据被窃取
- 包括英国航空公司、英国广播公司、普华永道等知名企业
- 超过 7700 万个人的数据被泄露
- 这是 2023 年最大的供应链攻击事件之一

**2024 年：AI 驱动的事件响应**
2024 年，生成式 AI 开始广泛应用于安全事件响应：
- 自动生成事件报告
- AI 分析攻击模式，推荐下一步行动
- 自动构建攻击时间线
- 但 AI 也有误判，需要人机配合

### NIST SP 800-61 事件响应生命周期详解

```
1. 准备（Preparation）
   - 建立响应团队和职责
   - 准备工具和文档
   - 演练响应流程
   - 建立沟通渠道

2. 检测与分析（Detection & Analysis）
   - 收集日志、告警、流量数据
   - 确定事件范围和严重程度
   - 识别攻击技术和攻击者
   - 验证事件是否真实（排除误报）

3. 遏制（Containment）
   - 隔离受影响系统（但不关闭，避免丢失证据）
   - 阻止攻击扩散
   - 保留证据

4. 根除（Eradication）
   - 清除恶意软件
   - 修补漏洞
   - 消除后门

5. 恢复（Recovery）
   - 恢复正常服务
   - 验证系统完整性
   - 监控是否再次被攻击

6. 经验教训（Lessons Learned）
   - 复盘事件过程
   - 更新防御措施
   - 改进响应流程
```

### 事件分级标准

```
严重（Critical）：
- 大规模数据泄露（超过 10 万人）
- 关键基础设施受损
- 国家级行为者的攻击
- 勒索软件导致业务完全中断

高（High）：
- 重要系统被完全控制
- 少量敏感数据泄露
- 攻击者获得管理员权限

中（Medium）：
- 部分系统受损
- 低敏感度数据泄露
- 攻击者获得普通用户权限

低（Low）：
- 单个系统或服务受影响
- 无数据泄露
- 攻击尝试被成功阻断
```

### 数字取证基础

```
内存取证（Memory Forensics）：
- 攻击者的 shell、进程、网络连接可能在内存中
- 使用 volatility 分析内存镜像
- 即使文件被删除，内存可能保留痕迹

磁盘取证（Disk Forensics）：
- 使用 Autopsy 或 Sleuth Kit 分析磁盘镜像
- 检查 deleted files、unallocated space
- Timeline 分析（文件修改时间线）

网络取证（Network Forensics）：
- PCAP 文件分析
- NetFlow 统计
- DNS 日志关联

日志取证（Log Forensics）：
- 时间线重建
- 日志完整性验证
- 跨日志源关联
```

### 事件响应的"灰色地带"

```
有些事情在事件响应中没有"标准答案"：

1. 支付赎金？
   - 联邦调查局（FBI）长期建议不要支付
   - 但很多公司权衡后仍然选择支付
   - 这是一个商业决策，不是技术决策

2. 通知用户还是"压下去"？
   - GDPR 要求 72 小时内通知
   - 但很多公司担心声誉损失
   - 这涉及法律、合规和公关的复杂平衡

3. 什么时候对外公布？
   - 发现后立即公布 vs. 等调查结束
   - 提前公布可能打草惊蛇
   - 延迟公布可能被批评"隐瞒"

这些问题的答案取决于组织的文化、规模和行业。
没有"放之四海而皆准"的正确答案。
```

## 实验环境

```bash
./student.sh  # 选择对应的实验开始
```

**目标服务**：
- Incident Lab：`http://127.0.0.1:8092`
- Nginx Lab：`http://127.0.0.1:8082`（关联分析）

**证据来源**：
- `logs/incident/incident.log` — 应用日志
- `logs/nginx/access.log` — Nginx 访问日志
- `evidence/incident/` — 预置证据文件

## 操作步骤

### 步骤 1：确认实验环境状态

```bash
# 确认服务运行
curl -s http://127.0.0.1:8092/ | head -20

# 确认日志目录存在
ls -la logs/incident/

# 查看预置证据
ls -la evidence/incident/
```

### 步骤 2：探索攻击面

#### 2.1 访问首页

```bash
curl -s http://127.0.0.1:8092/
```

**观察**：
- 返回的 HTML 内容
- 提示信息（如"Try /login?user=admin&password=wrong"）

#### 2.2 测试登录接口

```bash
# 测试错误凭据
curl -s "http://127.0.0.1:8092/login?user=admin&password=wrong"

# 测试正确凭据（根据代码分析，dev/Dev123 应该有效）
curl -s "http://127.0.0.1:8092/login?user=dev&password=Dev123"
```

**观察要点**：
- 错误密码的响应是什么？（`{"login": false}`）
- 正确密码的响应是什么？（`{"login": true}`）
- 是否有任何错误消息泄露账户信息？

**记录**：
```
测试 1：user=admin, password=wrong
响应：{"login": false}
分析：错误但不泄露用户是否存在

测试 2：user=dev, password=Dev123
响应：{"login": true}
分析：硬编码凭据导致认证成功
问题：这个凭据是从源代码泄露的，是否已在其他平台使用？
```

#### 2.3 测试管理接口

```bash
# 尝试访问管理导出功能（无需认证）
curl -s http://127.0.0.1:8092/admin/export

# 尝试一些常见的管理路径
curl -s http://127.0.0.1:8092/admin/
curl -s http://127.0.0.1:8092/manage/
curl -s http://127.0.0.1:8092/api/admin
```

**观察**：
- `/admin/export` 是否返回了敏感信息？
- 是否有任何认证提示（如"请先登录"）？

### 步骤 3：收集证据

#### 3.1 应用日志分析

```bash
# 查看 incident-lab 日志
cat logs/incident/incident.log
```

**预期日志格式**：
```
2026-05-10T09:00:00.000000Z 127.0.0.1 visit_index
2026-05-10T09:01:30.000000Z 127.0.0.1 login user=admin result=failed
2026-05-10T09:02:15.000000Z 127.0.0.1 login user=dev result=success
2026-05-10T09:03:00.000000Z 127.0.0.1 suspicious_admin_export
```

**分析要点**：
- 哪些 IP 访问了哪些接口？
- 失败登录和成功登录的比例
- 是否有可疑的管理操作？

#### 3.2 关联 Nginx 日志

```bash
# 查看相关时间段内 Nginx 的访问记录
grep "8092" logs/nginx/access.log || echo "Nginx 日志中没有 8092 端口的记录（因为是不同服务）"

# 如果攻击者通过 Web 界面进行操作，查看相关日志
cat logs/nginx/access.log | tail -30
```

#### 3.3 检查预置证据文件

```bash
# 查看预置证据目录内容
ls -la evidence/incident/

# 查看每个证据文件
cat evidence/incident/auth.log 2>/dev/null || echo "无 auth.log"
cat evidence/incident/web-access.log 2>/dev/null | head -30
```

### 步骤 4：构建攻击时间线

基于收集到的所有日志，构建完整的时间线：

```bash
# 合并所有日志并按时间排序
# 注意：不同日志的格式和时间格式可能不同

# 查看 incident.log 的时间格式
head -5 logs/incident/incident.log

# 对比 Nginx 的时间格式
head -5 logs/nginx/access.log
```

**时间线模板**：

| 时间（UTC） | 来源 | 事件 | 详情 | 严重程度 |
|------------|------|------|------|---------|
| 09:00:00 | incident | visit_index | 首页访问 | 低 |
| 09:01:30 | incident | login | 失败：user=admin | 中 |
| 09:02:15 | incident | login | 成功：user=dev | **高** |
| 09:03:00 | incident | suspicious_admin_export | 管理功能访问 | **极高** |

### 步骤 5：识别攻击阶段（Kill Chain 映射）

```bash
# 分析攻击者可能的行为链
# 1. 侦察（Reconnaissance）：扫描/探测
# 2. 初始访问（Initial Access）：利用漏洞或凭据登录
# 3. 横向移动（Lateral Movement）：访问更多资源
# 4. 目标达成（Actions on Objectives）：窃取数据/破坏系统
```

**Kill Chain 分析**：

```
攻击者行为：
1. 访问 http://127.0.0.1:8092/ （侦察）
2. 尝试 /login?user=admin&password=wrong （测试凭据）
3. 使用 dev/Dev123 成功登录 （初始访问）
4. 访问 /admin/export （横向移动/权限滥用）
5. 窃取数据或进一步攻击

对应的 Kill Chain 阶段：
侦察 → 武器化 → 投递 → 利用 → 安装 → 命令控制 → 目标达成
  │                                          │
  │                                          └── admin/export 被滥用
  └── 登录接口探测
```

### 步骤 6：提出遏制和加固方案

#### 6.1 立即遏制措施

```bash
# 如果这是真实事件，你的第一步行动是什么？

# 1. 隔离受影响系统（但不关闭，避免丢失证据）
docker pause incident-lab  # 暂停容器（保持内存状态）

# 2. 禁止 dev 账户的远程访问
# 在 docker-compose.yml 或 Dockerfile 中：

# 3. 网络隔离
# 确保 incident-lab 只能从特定 IP 访问
```

**遏制措施清单**：
```
□ 立即禁用 dev 账户（从源代码中删除硬编码凭据）
□ 在 /admin/export 添加认证检查
□ 限制 login 接口的失败次数（防止暴力破解）
□ 隔离容器，保留内存证据用于取证
□ 通知相关人员（安全团队、法务团队）
```

#### 6.2 长期加固建议

```bash
# 1. 凭据管理
# ❌ 错误：在代码中硬编码密码
ok = user == "dev" and password == "Dev123"

# ✅ 正确：使用环境变量或密钥管理服务
import os
valid_users = {
    "dev": os.environ.get("DEV_PASSWORD")
}
# 或使用专门的密钥管理（HashiCorp Vault、AWS Secrets Manager）


# 2. 访问控制（RBAC）
# ❌ 错误：无任何检查
@app.get("/admin/export")
def export():
    return "export started"

# ✅ 正确：检查用户角色
@app.get("/admin/export")
@login_required  # 装饰器验证登录
@role_required("admin")  # 装饰器验证角色
def export():
    return "export started"


# 3. 速率限制（防止暴力破解）
from flask_limiter import Limiter
limiter = Limiter(app, key_func=get_remote_address)

@app.get("/login")
@limiter.limit("5 per minute")  # 每分钟最多 5 次
def login():
    ...
```

## 技术原理

### 事件响应生命周期详解

```
1. 准备（Preparation）
   - 建立响应团队和职责
   - 准备工具和文档
   - 演练响应流程

2. 检测与分析（Detection & Analysis）
   - 收集日志、告警、流量数据
   - 确定事件范围和严重程度
   - 识别攻击技术和攻击者

3. 遏制（Containment）
   - 隔离受影响系统
   - 阻止攻击扩散
   - 保留证据

4. 根除（Eradication）
   - 清除恶意软件
   - 修补漏洞
   - 消除后门

5. 恢复（Recovery）
   - 恢复正常服务
   - 验证系统完整性
   - 监控是否再次被攻击

6. 经验教训（Lessons Learned）
   - 复盘事件过程
   - 更新防御措施
   - 改进响应流程
```

### 数字取证基础

```
内存取证（Memory Forensics）：
- 攻击者的 shell、进程、网络连接可能在内存中
- 使用 volatility 分析内存镜像
- 即使文件被删除，内存可能保留痕迹

磁盘取证（Disk Forensics）：
- 使用 Autopsy 或 Sleuth Kit 分析磁盘镜像
- 检查 deleted files、unallocated space
- Timeline 分析（文件修改时间线）

网络取证（Network Forensics）：
- PCAP 文件分析
- NetFlow 统计
- DNS 日志关联

日志取证（Log Forensics）：
- 时间线重建
- 日志完整性验证
- 跨日志源关联
```

## 思考题

### 思考题 1：事件响应中"遏制"为什么必须在"根除"之前？

**场景**：你发现服务器被入侵，第一反应是"彻底清除黑客的访问权限"（删除黑客的账户、修改所有密码）。

**问题**：
1. 如果你立即删除了黑客的 SSH 账户，但黑客已经安装了后门（rootkit），会发生什么？
2. 遏制和根除的顺序反过来会有什么风险？
3. 在什么情况下，你应该"先隔离再调查"而不是"先修复再调查"？

### 思考题 2：硬编码凭据的风险

**问题**：
1. `dev/Dev123` 这个凭据是在源代码中硬编码的。如果你是安全工程师，你如何发现这个风险？（提示：代码审计、SAST 工具、依赖扫描）
2. 即使 `Dev123` 是强密码（大小写+数字），为什么在源代码中硬编码仍然危险？
3. 如果这是一个 GitHub 仓库中的代码，你如何在密码泄露前发现它？（提示：GitHub Secret Scanning）

### 思考题 3：无认证的管理接口

**OWASP 术语**：这种漏洞叫什么？

- **BOLA**（Broken Object Level Authorization）：用户可以访问不属于他们的对象
- **BFLA**（Broken Function Level Authorization）：用户可以执行不属于他们角色的功能
- **IDOR**（Insecure Direct Object Reference）：直接引用对象，没有权限检查

**问题**：
1. `/admin/export` 属于哪种漏洞？
2. 它和"水平越权"和"垂直越权"是什么关系？
3. 除了添加认证，还有什么方式可以防御这类漏洞？

### 思考题 4：事件响应中的证据完整性

**场景**：你收集了日志文件，但攻击者可能已经修改了它们。

**问题**：
1. 如何证明你收集的日志没有被篡改？（提示：哈希校验、数字签名）
2. 如果日志在远程服务器上（不是本地），你如何确保取证过程中日志不被修改？
3. 在法律诉讼场景中，证据完整性的重要性是什么？为什么需要建立"证据链"（Chain of Custody）？

## 交付物

1. **事件报告**（完整格式见下方）
2. **攻击时间线**（包含所有日志源的证据）
3. **IOC 清单**（攻击者 IP、使用的凭据、访问的路径）
4. **遏制计划**（立即行动 + 长期加固）
5. **思考题答案**

## 事件报告模板

```markdown
# 【事件报告】INC-20260510-001

## 基本信息
- 事件编号：INC-20260510-001
- 事件等级：[严重/高/中/低]
- 发现时间：2026-05-10 09:00 UTC
- 报告人：[你的姓名]

## 摘要
[用 2-3 句话描述发生了什么，包括攻击者做了什么、影响了什么]

## 攻击时间线
| 时间 | 来源 | 事件 | 证据 |
|------|------|------|------|
| HH:MM | incident.log | login success | logs/incident/incident.log |

## 受影响系统
- 系统/服务名称
- IP 地址
- 影响范围（哪些数据/功能受影响）

## 初始访问向量
[攻击者是如何进入系统的？]
- 凭据泄露（dev/Dev123）
- 漏洞利用（无认证访问 /admin/export）

## 横向移动路径
[攻击者进入后的移动路径]

## 数据泄露评估
[是否有数据被窃取？泄露了多少？]

## 遏制措施
- [ ] 立即：禁用 dev 账户
- [ ] 立即：添加 /admin/export 认证
- [ ] 短期：实施速率限制

## 加固建议
1. [具体技术措施]
2. [具体技术措施]

## IOC 指标
- 攻击者 IP：127.0.0.1（本实验）
- 恶意凭据：dev/Dev123
- 恶意访问：/admin/export

## 复盘问题
1. 为什么硬编码凭据没有被代码审查发现？
2. 为什么无认证接口没有被测试发现？
3. 下次如何防止类似事件？
```

## 工具速查

```bash
# 访问目标服务
curl http://127.0.0.1:8092/
curl "http://127.0.0.1:8092/login?user=dev&password=Dev123"
curl http://127.0.0.1:8092/admin/export

# 日志分析
cat logs/incident/incident.log
tail -f logs/incident/incident.log  # 实时监控

# 关联分析
grep "login" logs/incident/incident.log
grep "admin" logs/incident/incident.log

# 容器操作（谨慎使用）
docker pause incident-lab   # 暂停（保留证据）
docker exec -it incident-lab cat /app/logs/incident.log
```