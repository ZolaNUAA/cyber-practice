# Lab03：认证审计

## 学习目标

1. 理解 SSH 弱密码认证的风险
2. 掌握 Docker 日志中的认证信息提取方法
3. 分析 SSH 暴力破解的检测与防御
4. 评估常见密码策略的有效性

## 预备知识

### 密码的历史：1960s 到 2020s

**1960s：CTSS 与明文密码的诞生**
1961 年，MIT 开发了 CTSS（兼容分时系统），引入了世界上第一个计算机密码。设计者 Fernando Corbató 的想法很简单：给每个用户分配一个密码，这样多人共享同一台计算机时就能"各自看到各自的东西"。但他当时没想到的是：这个系统把密码明文存储在一个任何用户都可读的文件里。2022 年，Fernando Corbató 在接受《连线》采访时说："密码是我这辈子最后悔的发明。"原因：它带来无穷无尽的安全问题，却几乎无法完全解决。

**1970s：UNIX 密码 shadow 化**
1974 年，UNIX 系统开始把加密后的密码 hash 存储在 `/etc/shadow` 中，不再存放在 `/etc/passwd`（这个文件需要可读，用于用户名称解析）。但实际上，当时使用的 crypt() 函数只能用 DES 算法的最后 8 个字符——这意味着无论你的密码多长，只有前 8 个字符被用于加密。这就是为什么早期的 UNIX 密码被限制为 8 个字符。

**1990s：彩虹表（Rainbow Tables）的发明**
1999 年，比利时密码学家 Philippe Oechslin 发表了论文，提出了"时间-存储权衡"攻击方法。彩虹表的核心思想：用巨大的存储空间换取计算时间——预先计算所有可能的密码组合的 hash 值，然后对比要破解的 hash 即可瞬间得到原始密码。2003 年，一张学专用的 DVD 可以存放 92% 的 Windows XP 密码对应的彩虹表。

**2000s：GPU 加速的密码破解**
2012 年，Security Horizon 测试：用一块 ATI Radeon HD 7970 显卡，每秒可以计算 83 亿次 bcrypt 哈希——这意味着任何 8 字符的密码在 6 小时内就可以被穷举破解。今天，一台普通的游戏 PC 可以在 1 分钟内破解一个 MD5 加密的"强密码"。

**2010s：SQL 注入 + 弱哈希 = 灾难**
2011 年，LinkedIn 泄露了 650 万个 SHA1（无盐）加密的密码密码。安全专家很快发现，有超过 30 万个密码可以立即通过彩虹表反查，包括 "linkedin"、"password" 等。更糟糕的是，2016 年 LinkedIn 再次泄露，这次是 1.17 亿个账户——攻击者通过"密码重用"攻击，用这批密码去测试用户在其他网站上的账户。结果发现，很多人的密码在不同网站是相同的。

**2020s：Passkeys 的崛起**
2022 年，Google、Apple、Microsoft 联合宣布支持 Passkeys（基于 FIDO2/WebAuthn 标准）。Passkeys 的核心是"公私钥对"：服务器只存储公钥，你的设备存储私钥。登录时，服务器发送一个随机挑战，你的设备用私钥签名后发回——整个过程，你的私钥从未在网络中传输。2024 年，Google 报告：已有超过 4 亿个 Google 账户启用了 Passkeys，登录速度比传统密码快 40%。

### 暴力破解的历史与趣事

**案例 1：2019 年 Capital One 数据泄露**
攻击者 Paige Thompson 利用 AWS 的 SSRF（服务器端请求伪造）漏洞获取了管理员凭证，访问了 Capital One 的 S3 bucket，获取了 1.06 亿用户的敏感数据。关键问题是：Capital One 的 WAF（Web 应用防火墙）配置错误，允许了本不应该允许的请求。最终，Capital One 被罚款 8 亿美元。但更有趣的是：这笔罚款中的 2.5 亿美元由保险公司赔付——Capital One 之前买了网络安全保险。

**案例 2：2022 年 Dropbox 的暴力破解防御**
Dropbox 公开了他们的登录安全架构：每个账户有 10 次密码尝试的机会，超过后账户被锁定并需要邮箱验证。但有趣的是：Dropbox 的安全团队发现，即便限制密码尝试次数，攻击者仍然可以通过"凭证填充"（Credential Stuffing）攻击——用从其他网站泄露的账户密码批量尝试，因为很多人会在多个网站使用相同的密码。

**案例 3：2024 年 Microsoft Authenticator 的"无密码"政策争议**
2024 年，Microsoft 宣布所有 Azure AD 管理员必须使用无密码登录（Passkeys 或 Windows Hello）。但安全研究员发现了一个问题：如果攻击者能够访问你的 Outlook 邮箱（通过其他网站的密码泄露），他们可以通过"邮箱恢复"流程重置你的 Microsoft 账户——这意味着 Passkeys 的安全性实际上取决于你的邮箱安全。

### 全球 SSH 暴力破解统计

```
你知道你的 SSH 服务器一开机就会有多少次暴力破解尝试吗？

根据 Shodan 和 F-Secure 的 2024 年数据：

全球 SSH 暴露在公网的服务器：约 1,420 万台
平均每台服务器每天被扫描次数：约 15 次
平均首次暴力破解攻击发生时间：暴露后 3 分钟内
全球每秒 SSH 暴力破解尝试次数：约 800-1200 次

最常见的攻击目标用户名（TOP 5）：
1. root (约 23%)
2. admin (约 18%)
3. ubuntu (约 8%)
4. test (约 5%)
5. guest (约 3%)

最常见的攻击目标密码（TOP 5）：
1. admin (约 1.2%)
2. password (约 0.9%)
3. 123456 (约 0.7%)
4. root (约 0.5%)
5. (空密码) (约 0.3%)

有趣的事实：
- 攻击者已经开始使用 AI 生成"智能密码字典"，基于目标公司的名称、行业、成立年份生成候选密码
- 2023 年，研究者发现一个僵尸网络使用了一种奇怪的策略：它们只在凌晨 2-4 点发起攻击，利用"低峰期管理员不在线"的特点
```

### 认证安全的未来趋势

**1. 零知识证明（ZKP）与隐私保护认证**
零知识证明允许你"证明你知道密码"，但不需要把密码发给验证方。2023 年，Cloudflare 推出了"区域验证"功能，使用 ZKP 技术让你的浏览器和服务器之间的通信即使被截获也无法被破解。目前这项技术仍在早期阶段，但在密码管理器和隐私保护场景中有很大的潜力。

**2. 生物识别 + 行为分析的"连续认证"**
传统的认证是"一次性"的——你登录一次，然后你有权限。但 2024 年，Apple 和 Google 开始实验"连续认证"：即使登录成功后，系统会持续分析你的打字节奏、鼠标移动模式、触控力度等生物特征，如果发现"行为异常"，自动要求二次验证。这种方法的优点是：即使密码泄露，攻击者也难以复制你的行为特征。

**3. 量子安全认证**
2024 年，NIST 发布了第一批量子抗性算法标准（包括 CRYSTALS-Kyber、CRYSTALS-Dilithium）。这些算法可以在量子计算机普及后仍然保护认证安全。NIST 的建议：现在开始部署，双轨策略（当前算法 + 量子抗性算法），等待全面迁移。

**4. 暴力破解的"智能化"趋势**
2024 年，安全公司 Sophos 报告了第一批使用 AI 的自动化暴力破解攻击：AI 模型通过分析目标网站的响应时间差异（timing attack），在尝试密码之前就能"预测"哪些密码组合成功的概率更高。实验结果显示，这种方法比传统暴力破解效率提高了约 15 倍，但产生的流量更少、更难被检测。

### 认证安全的最佳实践

```
防御者的检查清单：

1. 密码策略
   ❌ 强制要求特殊字符和数字（用户会变成 p@ssw0rd123!）
   ✅ 使用密码管理器 + 长密码（20+ 随机字符）
   ✅ 启用密码泄露检测（HaveIBeenPwned API）

2. 多因素认证（MFA）
   ❌ 短信验证码（SIM Swapping 攻击）
   ✅ TOTP（Google Authenticator）或 Passkeys
   ✅ 硬件安全密钥（YubiKey）

3. 暴力破解防护
   ❌ 只限制密码错误次数
   ✅ 使用 CAPTCHA + 限速 + 异常检测
   ✅ 监控"凭证填充"攻击模式（短时间内大量不同账户的同密码尝试）

4. SSH 安全
   ❌ 密码登录 + 默认端口
   ✅ 公钥认证 + 证书 + 非默认端口
   ✅fail2ban 或等同于动态封锁

最后一条建议：
去看看 HaveIBeenPwned.com，输入你的邮箱。
如果你的邮箱出现在数据泄露中，你的密码可能已经在攻击者的密码字典里了。
```

## 实验环境

```bash
./student.sh  # 选择对应的实验开始
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