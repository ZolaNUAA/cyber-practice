# Lab12：事件响应

## 学习目标

1. 理解事件响应的完整生命周期（NIST SP 800-61）
2. 掌握从证据收集到报告撰写的完整流程
3. 能够基于日志和告警构建攻击时间线
4. 提出有效的遏制和长期加固方案

## 预备知识

### 事件响应的发展历史

**1988 年 Morris Worm 事件**：
- 首个大规模互联网蠕虫，6000 台计算机瘫痪
- 导致美国政府建立 CERT（计算机应急响应小组）
- 催生了现代事件响应学科

**NIST SP 800-61 事件响应生命周期**：

```
┌────────────┐    ┌─────────────┐    ┌──────────────┐
│  准备阶段   │───▶│ 检测与分析  │───▶│ 遏制与根除   │
│Preparation │    │Detection&Analysis│Containment&Eradication│
└────────────┘    └──────┬──────┘    └──────┬───────┘
                         │                    │
                    ┌────▼──────┐        ┌────▼───────┐
                    │  恢复     │◀───事件│  经验教训   │
                    │Recovery   │关闭   │Lessons Learned│
                    └───────────┘        └────────────┘
```

### 本实验的攻击场景

incident-lab 服务存在以下漏洞：

```python
# services/incident-lab/app.py 关键代码

@app.get("/login")
def login():
    user = request.args.get("user", "-")
    ok = user == "dev" and request.args.get("password") == "Dev123"  # ← 硬编码凭据
    log(f"login user={user} result={'success' if ok else 'failed'}")
    return {"login": ok}

@app.get("/admin/export")
def export():
    log("suspicious_admin_export")  # ← 无任何认证！
    return "export started"
```

**漏洞分析**：
1. `/login` 中硬编码 `dev/Dev123` 密码（凭据泄露）
2. `/admin/export` 无任何权限验证，任何人都可访问（失效的访问控制）
3. 登录日志可被用于用户枚举

## 实验环境

```bash
./reset-lab.sh lab12
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