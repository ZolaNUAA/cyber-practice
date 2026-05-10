# Lab03：认证审计

## 学习目标

1. 理解 SSH 弱密码认证的风险
2. 掌握 Docker 日志中的认证信息提取方法
3. 分析 SSH 暴力破解的检测与防御
4. 评估常见密码策略的有效性

## 预备知识

### 弱密码：数据泄露的头号原因

根据 **Verizon DBIR 2023**，弱密码或被盗密码是 **86%** 的 Web 应用攻击和 **17%** 的所有数据泄露的根本原因。

**2023 年最常用密码 TOP 10**：
```
1. 123456
2. password
3. 12345678
4. qwerty
5. 123456789
6. 12345
7. 1234567
8. 111111
9. 1234567
10. abc123
```

**经典案例：Mirai 僵尸网络（2016）**
Mirai 感染了约 50 万台 IoT 设备（摄像头、路由器）。感染方式：**SSH/Telnet 弱密码**（admin/admin、root/root 等默认凭据）。随后发起 Dyn DNS DDoS 攻击，导致 Twitter、GitHub、Netflix 等全面瘫痪。

### SSH 暴力破解统计

- 全球每天约 **800 万次** SSH 暴力破解尝试
- SSH 服务暴露在互联网的平均 **3 分钟**内被首次扫描
- 默认端口 22 的 SSH 服务尤其危险

### 本实验认证流程

```
学生 Kali 主机                    ssh-lab 容器（22 端口）
      │                                    │
      │──── SSH Banner 请求 ──────────────▶│
      │◀─── SSH-2.0-OpenSSH_8.4 ───────────│
      │                                    │
      │──── 发送用户名: student ──────────▶│
      │◀─── 密码挑战（password request）────│
      │                                    │
      │──── 密码: 123456 (错误) ──────────▶│
      │◀─── Permission denied ─────────────│
      │                                    │
      │──── 密码: Student123 (正确) ──────▶│
      │◀─── Welcome to Ubuntu ─────────────│
```

**实验凭据**：
- 用户名：`student`
- 密码：`Student123`

## 实验环境

```bash
./reset-lab.sh lab03
```

**目标**：`ssh student@127.0.0.1 -p 2222`

## 操作步骤

### 步骤 1：确认 SSH 服务

```bash
# 查看 SSH 版本（Banner 信息）
ssh -V -p 2222 127.0.0.1 2>&1 | head -1

# nmap 扫描确认服务
nmap -sV -p 2222 127.0.0.1
```

**观察要点**：
- 服务是否在 2222 端口运行
- SSH 版本（OpenSSH_8.4）
- 端口状态（open/closed）

**你应该记录**：
```
PORT     STATE  SERVICE  VERSION
2222/tcp open   ssh      OpenSSH 8.4 (Ubuntu)
```

### 步骤 2：尝试错误密码（观察认证失败）

```bash
ssh student@127.0.0.1 -p 2222
# 输入密码: 123456 （错误密码）

# 预期输出：
# student@127.0.0.1's password:
# Permission denied, please try again.
```

**观察要点**：
- SSH 提示了"密码错误"，但没有说"用户名不存在"
- 这本身就是一个信息泄露（攻击者可以确认 `student` 用户存在）

**记录**：
```
错误密码 "123456" 尝试结果：Permission denied
用户存在性确认：✅ student 账号存在（而非返回"用户不存在"）
```

### 步骤 3：使用正确密码登录

```bash
ssh student@127.0.0.1 -p 2222
# 输入密码: Student123 （正确）

# 预期输出：
# Welcome to Ubuntu 22.04.3 LTS (GNU/Linux 5.15.0-94-generic x86_64)
# student@container:~$
```

**操作中观察**：
- 登录成功后看到什么？（系统信息、用户提示符）
- 登录后可以执行哪些命令？（`whoami`、`pwd`、`ls`）

```bash
# 登录成功后执行
whoami      # 当前用户
pwd         # 当前目录
ls -la      # 主目录内容
cat /etc/passwd | grep student  # 查看用户信息
```

**你应该记录**：
```
登录状态：✅ 成功
当前用户：student
用户 ID：uid=1001(student) gid=1001(student) groups=1001(student)
主目录：/home/student
可访问的 Shell：/bin/bash
```

### 步骤 4：检查 Docker 容器日志（SSH 认证记录）

**关键**：SSH 认证日志保存在 Docker 容器的日志中，而不是宿主机的系统日志。

```bash
# 查看 ssh-lab 容器的所有日志
docker logs ssh-lab 2>&1 | tail -n 100

# 专门筛选认证相关的日志
docker logs ssh-lab 2>&1 | grep -E "Accepted|Failed|password"
```

**预期输出示例**：
```
May 10 09:23:01 ssh-lab sshd[123]: Failed password for student from 127.0.0.1 port 51422 ssh2
May 10 09:23:05 ssh-lab sshd[123]: Accepted password for student from 127.0.0.1 port 51424 ssh2
```

**你应该记录**：
```
日志条目 1：Failed password for student from 127.0.0.1 port 51422
  - 事件：认证失败
  - 用户：student
  - 源 IP：127.0.0.1
  - 源端口：51422
  - 时间：[10/May/2026:09:23:01]

日志条目 2：Accepted password for student from 127.0.0.1 port 51424
  - 事件：认证成功
  - 用户：student
  - 源 IP：127.0.0.1
  - 源端口：51424
  - 时间：[10/May/2026:09:23:05]
```

### 步骤 5：分析认证时间线

```bash
# 按时间顺序查看认证事件
docker logs ssh-lab 2>&1 | grep -E "Failed|Accepted" | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}'

# 查看认证失败次数统计
docker logs ssh-lab 2>&1 | grep "Failed password" | wc -l

# 查看认证成功次数
docker logs ssh-lab 2>&1 | grep "Accepted password" | wc -l
```

**你应该记录**：
```
认证失败次数：X 次
认证成功次数：1 次（你的登录）
攻击者尝试了多少个不同密码？
```

## 技术原理

### SSH 认证过程

```
1. TCP 连接建立（三次握手）
2. SSH 版本交换（Banner）
3. 密钥协商（加密算法握手）
4. 用户认证
   - 客户端发送用户名
   - 服务器返回认证方法列表（password/publickey/keyboard-interactive）
   - 客户端选择一种方法（如 password）
   - 客户端发送加密的密码
   - 服务器验证
5. 认证成功 → 建立会话（shell/command/sftp）
```

### 用户枚举漏洞（Username Enumeration）

**问题**：SSH 服务对"用户名不存在"和"密码错误"返回不同的响应。

```
正确用户名 + 错误密码 → "Permission denied"
错误用户名 + 错误密码 → "Permission denied"

但是，响应时间不同（正确用户名处理密码更久）
或者错误消息细节不同
```

**攻击者利用**：通过计时分析或消息差异，攻击者可以确认服务器上存在哪些用户名，然后针对这些用户暴力破解密码。

### 防御方案

| 措施 | 配置方法 | 效果 |
|------|---------|------|
| **强密码策略** | `password quality check`，要求 12+ 位混合 | 暴力破解难度指数上升 |
| **密钥认证** | `PubkeyAuthentication yes`，禁用密码 | 完全规避暴力破解 |
| **Fail2Ban** | 5 次失败后封禁 IP 10 分钟 | 大幅降低暴力破解效率 |
| **端口变更** | 22 改为高位随机端口 | 减少自动化扫描触发 |
| **禁止 root 登录** | `PermitRootLogin no` | 限制成功后的最高权限 |
| **限制用户** | `AllowUsers student` | 仅允许特定用户登录 |

**/etc/ssh/sshd_config 强化配置**：
```bash
PermitRootLogin no
PasswordAuthentication no          # 完全禁用密码认证
PubkeyAuthentication yes
MaxAuthTries 3                     # 最多尝试 3 次
AllowUsers student alice
ClientAliveInterval 300            # 5 分钟无活动断连
```

**Fail2Ban 配置**：
```bash
# /etc/fail2ban/jail.local
[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 600                     # 封禁 10 分钟
findtime = 600                    # 10 分钟内超过 3 次则封禁
```

## 思考题

### 思考题 1：为什么即使密码强度很高，SSH 暴力破解仍然危险？

**场景**：假设你的密码是 `Tr0ub4dor_3&9x!QjK`（15 位随机字符），从密码学角度几乎无法暴力破解，但某企业仍有 500 台服务器被攻击者拿下。

分析可能的攻击路径（提示：考虑内网环境和企业 SSRF 漏洞、键盘记录木马、密码复用等）。

### 思考题 2：Docker 容器日志 vs. 宿主机日志

本实验中我们通过 `docker logs` 查看 SSH 认证信息，而不是 `/var/log/auth.log`。

**问题**：
1. 为什么 ssh-lab 容器的 SSH 日志不在宿主机的 `/var/log/auth.log` 中？
2. 如果攻击者获得了容器内的 root 权限，并删除了 `docker logs`（`docker logs --tail 0 ssh-lab` 清空日志），还有哪些方式可以找到认证记录？
3. 这种"日志不在宿主机"的设计，对安全运营有什么影响？

### 思考题 3：密码策略的有效性评估

假设有以下密码策略：

| 策略 | 规则 | 实际效果 |
|------|------|---------|
| A | 要求 8 位以上 | 仍可使用 `12345678` |
| B | 要求大小写+数字 | 仍可使用 `Password123` |
| C | 要求 12 位 + 特殊字符 | 仍可使用 `P@ssword123!`（符合规则但已在泄露库中）|

**问题**：密码策略能解决"弱密码"问题吗？真正的安全密码是什么样的？为什么密码管理器比"复杂密码"更安全？

### 思考题 4：Fail2Ban 的局限性

Fail2Ban 是对抗暴力破解的常用工具，但它能防止以下情况吗？

1. **分布式暴力破解**（每个 IP 只尝试 2 次，分散在 1000 个 IP）
2. **Credential Stuffing（凭据填充）**（攻击者使用从其他网站泄露的正确用户名:密码对）
3. **Slow HTTP Brute Force**（每 30 秒尝试一次，用一年时间遍历所有可能密码）

对于每种情况，提出你的改进建议。

## 交付物

1. **认证失败日志截图**（错误密码尝试）
2. **认证成功日志截图**（正确密码登录）
3. **登录后系统信息**（whoami、pwd、ls 输出）
4. **认证时间线分析**（失败→成功的完整过程）
5. **防御方案清单**（至少 5 条措施）
6. **思考题答案**（不少于 3 题）

## 工具速查

```bash
# SSH 连接
ssh student@127.0.0.1 -p 2222           # 交互式登录
ssh -V -p 2222 127.0.0.1 2>&1          # 仅查看 Banner

# 容器日志
docker logs ssh-lab 2>&1 | tail -50    # 查看最近 50 条日志
docker logs ssh-lab 2>&1 | grep -E "Accepted|Failed"  # 筛选认证事件
docker logs --follow ssh-lab 2>&1      # 实时跟踪日志

# 日志分析
awk '/Failed password/' logs/auth.log | awk '{print $1,$2,$3,$11,$13}' | head
# 统计每个 IP 的失败次数
grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -rn

# nmap 检测
nmap -sV -p 2222 127.0.0.1
```