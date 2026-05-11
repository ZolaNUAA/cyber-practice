# Lab08：Linux 特权最小化

## 学习目标

1. 理解最小权限原则（Principle of Least Privilege）的核心概念
2. 掌握 Linux 文件权限和所有权的审计方法
3. 学会分析 sudo 规则并评估其安全性
4. 能够提出基于最小权限原则的系统加固方案

## 预备知识

### 最小权限原则的历史：从军方的"知其必要"到云原生

**1975 年：Saltzer 和 Schroeder 的原版论文**
1975 年，Jerome Saltzer 和 Michael Schroeder 在《The Protection of Information in Computer Systems》中首次系统性地提出了"最小权限原则"（Principle of Least Privilege）。论文的核心观点是："每个程序和每个用户都应该使用完成工作所需的最小权限集。"这篇论文比很多攻击工具的诞生还早，但它描述的原理在今天仍然完全适用——包括容器逃逸、横向移动、特权升级等现代攻击模式。

**1980s：Unix 的 SUID/SGID 机制**
1980 年代，Unix 系统引入了 SUID（Set User ID）和 SGID（Set Group ID）机制——允许程序在执行时以文件所有者或所属组的身份运行。比如，`passwd` 命令需要修改 `/etc/passwd` 或 `/etc/shadow` 文件，这些文件普通用户无权修改，但 `passwd` 命令是 root 拥有的 SUID 程序，所以普通用户可以通过它间接修改自己的密码。问题在于：如果 SUID 程序存在漏洞，攻击者可以借此获得 root 权限。

**1988 年：Morris Worm 与最小权限的教训**
1988 年的 Morris Worm 蠕虫感染了美国约 10% 的互联网计算机（当时互联网只有 6 万台主机）。蠕虫利用了 finger 守护进程的一个漏洞，但真正的问题在于：finger 守护进程竟然以 root 身份运行——这是完全不必要的。如果它以普通用户身份运行，蠕虫即使利用了漏洞也只能获得普通用户权限，无法传播到整个系统。Morris Worm 直接催生了 CERT（计算机应急响应小组）的诞生。

**1996 年：CDE（Common Desktop Environment）的 dtspcd 漏洞**
1996 年，CDE 的一个后台守护进程 `dtspcd` 被发现存在缓冲区溢出漏洞。更糟的是，`dtspcd` 竟然是以 root 身份运行的，这使得任何能够连接到它的用户都能获得 root shell。这个漏洞在 2002 年才被正式修复，在那之前，互联网上成千上万的 Unix 工作站都处于危险之中。

**2005 年：Sudo 的 "sudoedit" 漏洞**
2005 年，sudo 工具被发现存在一个允许权限提升的漏洞。问题的根源在于：`sudoedit` 命令在处理符号链接时存在 TOCTOU（Time-of-Check-Time-of-Use）竞争条件，攻击者可以利用它在修改文件时绕过安全检查。这个漏洞让任何有 sudo 权限的用户都能获得 root 权限——这与最小权限原则完全相悖：如果用户的权限本来就不需要那么高，问题就不存在。

**2009 年：阿联酋的人权活动家被 "FinFisher" 间谍软件监控**
2009 年，阿联酋的人权活动家 Ahmed Mansoor 收到了一条短信，里面包含了一个链接。他点开了链接，安装了一个叫做 "FinFisher" 的间谍软件。这个软件利用了 iOS 的多个漏洞，获得了设备的完全控制权。但更令人震惊的是后续发现：FinFisher 的服务器居然安装在 IBM 和 Verizon 的服务器上——这两家公司显然没有遵循最小权限原则，让他们的服务器被用于人权侵犯。

**2014 年：X.org 的 SUID 配置错误**
2014 年，X.org（Linux 图形系统的核心组件）被发现有多个 SUID 配置错误，导致普通用户可以提升到 root 权限。问题的根本原因：X.org 需要访问显示硬件，但这种需求并不意味着它需要 root 权限——如果它被部署在更受限的沙箱中，问题就不会存在。

**2017 年：Equifax 与"以 root 运行"的应用**
2017 年的 Equifax 数据泄露中，攻击者利用 Apache Struts 漏洞获得了 Web 应用的访问权限。问题的关键在于：这个应用竟然是以 root 身份运行的！攻击者一旦进入应用，不需要任何额外的横向移动或权限提升，直接就是 root。这完全违背了最小权限原则——如果 Web 应用是以低权限用户（如 www-data）运行的，攻击者至少还需要再挖一个漏洞才能获得系统权限。

**2019 年：Docker 容器逃逸与特权容器**
2019 年，多个 Docker 容器逃逸漏洞被披露——这些漏洞都涉及"特权容器"（privileged container）的概念。特权容器是一种以 `--privileged` 标志启动的容器，它禁用了大部分安全隔离，获得了几乎与宿主机相同的权限。安全研究者发现，在特权容器中，攻击者可以很容易地通过设备映射（如 `/dev/sda`）访问宿主机的整个文件系统，甚至可以修改宿主机的内核参数。正确的做法是：永远不要使用 `--privileged` 标志，改用 `--cap-drop=ALL` 明确限制权限。

**2020 年：Azure 的权限配置错误**
2020 年，多起 Azure 平台的安全事件被披露——管理员在配置云资源时，错误地给某些服务赋予了过高的权限。比如，一个 Azure Functions 应用本应该只需要读写某个特定的 Blob Storage，但实际上它被赋予了管理整个存储账户的权限。一旦应用存在代码注入漏洞，攻击者可以利用这个过高的权限窃取整个存储账户中的数据，甚至横向移动到其他云资源。

**2023 年：Kubernetes RBAC 的"过度权限"**
2023 年，Orca Security 的研究报告显示，在他们扫描的 Kubernetes 集群中，**62%** 的服务账户被赋予了比实际需要更高的权限。这在云原生环境中是"最小权限原则"被违反的典型案例。问题在于：开发者在调试时为了方便会给服务账户赋予 `cluster-admin` 角色，然后忘记在生产环境中把它改回来。

### sudo 配置错误的经典案例

```
# /etc/sudoers 中的危险配置
alice ALL=(ALL) NOPASSWD: /usr/bin/vim
# vim 可以通过 :sh 获得 root shell

bob ALL=(ALL) NOPASSWD: /usr/bin/less
# less 可以通过 !command 获得 root shell

charlie ALL=(ALL) NOPASSWD: /bin/cat
# cat 可以读取任意文件，包括 /etc/shadow
```

### 本实验的 sudoers 规则

```
analyst ALL=(root) NOPASSWD: /usr/local/bin/backup-app
```

问题分析：
1. **NOPASSWD**：analyst 执行 backup-app 时无需输入密码，可自动化执行
2. **绝对路径**：限制为特定程序，理论上是好的设计
3. **但是**：backup-app 内部执行什么操作？它能读写哪些文件？

```bash
# backup-app 的实际内容
/bin/tar -czf /tmp/app-backup.tgz /opt/app 2>/dev/null
```

### 特权升级攻击的"现代形态"

**1. SUID/SGID 滥用**
如果一个 SUID 程序可以被利用，攻击者可以：
```bash
# 利用 vim SUID 提权
:!/bin/bash
# 获得以 root 运行的 shell
```

**2. 能力（Capabilities）滥用**
Linux 的 capabilities 机制把 root 权限分解为多个独立的能力。但很多服务只需要部分能力，却拥有全部。比如，如果一个进程拥有 `CAP_SYS_ADMIN`，它可以执行几乎任何特权操作。

**3. Docker Socket 滥用**
Docker 守护进程通过 Unix socket 通信（默认 `/var/run/docker.sock`）。如果攻击者可以访问这个 socket，他可以：
```bash
docker run -v /:/host alpine chroot /host
# 获得宿主机的 root shell
```

**4. 共享命名空间（Namespace）滥用**
容器共享宿主机的某些命名空间（如 PID、Network）。如果容器可以创建新的 PID 命名空间然后与宿主机共享，攻击者可以"跳出"容器的隔离。

### 最小权限的防御哲学

```
防御者的检查清单：

1. 永远不要以 root 运行 Web 应用
   ❌ user: root in docker-compose.yml
   ✅ user: 10001:10001 (专用低权限用户)

2. 定期审计 SUID/SGID 文件
   ❌ 从不检查
   ✅ 每季度运行 find / -perm -4000 -o -perm -2000

3. 审计 sudo 规则
   ❌ 从不检查
   ✅ 使用 sudo -l 定期检查自己有哪些权限
   ✅ 检查 /etc/sudoers 是否有过多 NOPASSWD 规则

4. Docker 安全配置
   ❌ docker run --privileged
   ✅ docker run --cap-drop=ALL --read-only
   ✅ 使用 AppArmor/SELinux 限制容器能力

5. Kubernetes RBAC
   ❌ 给所有服务账户 cluster-admin
   ✅ 使用 Role/RoleBinding，仅授予必要的权限
   ✅ 定期运行 kubectl auth can-i 检查权限

有趣的事实：
美国军方有一个"知其必要"（Need-to-Know）原则，
和最小权限原则非常类似，但针对的是信息访问。
这意味着，即使你有权限访问某些信息，
如果你不需要知道，你也不应该访问。
这个原则在信息安全中被称为 "Bell-LaPadula 模型" 的基础。
```

## 实验环境

```bash
./student.sh  # 选择对应的实验开始
docker exec -it priv-lab bash

# 登录身份：analyst（低权限用户）
# 当前用户：uid=1001(analyst)
```

**重要**：这是一个无端口暴露的容器，必须通过 `docker exec` 进入。

## 操作步骤

### 步骤 1：确认当前身份和权限

```bash
# 查看当前用户身份
id

# 预期输出：
# uid=1001(analyst) gid=1001(analyst) groups=1001(analyst)
```

**记录**：
```
用户名：analyst
UID：1001
GID：1001
所属组：analyst
是否是 root：否（uid != 0）
```

### 步骤 2：查看 sudo 规则

```bash
# 查看当前用户可以执行哪些 sudo 命令
sudo -l

# 预期输出：
# User analyst may run the following commands on priv-lab:
#     (root) NOPASSWD: /usr/local/bin/backup-app
```

**分析**：
```
analyst 可以免密码以 root 身份执行 /usr/local/bin/backup-app

这意味着：
1. 如果攻击者获得 analyst 账户，可以自动化提权（不需要密码）
2. backup-app 是否安全决定了提权风险的大小
3. analyst 不需要知道 root 密码，但可以以 root 身份执行 backup-app
```

### 步骤 3：分析 backup-app 的实际行为

```bash
# 查看 backup-app 的内容（以当前用户身份）
cat /usr/local/bin/backup-app

# 预期输出：
# #!/bin/sh
# /bin/tar -czf /tmp/app-backup.tgz /opt/app 2>/dev/null
```

**分析**：
```bash
# backup-app 执行 tar 备份 /opt/app 到 /tmp/app-backup.tgz
# 问题 1：tar 命令是否安全？
# 问题 2：analyst 能访问 /tmp/app-backup.tgz 吗？
# 问题 3：/opt/app 目录的权限是什么？
```

### 步骤 4：检查文件权限和所有权

```bash
# 查看 /opt 目录结构
ls -la /opt/

# 查看 /opt/backups 目录（包含敏感文件）
ls -la /opt/backups/

# 查看 /opt/backups/app.env 的内容
cat /opt/backups/app.env

# 检查文件权限
stat /opt/backups/app.env
```

**预期输出**：
```
-r-------- 1 root analyst  ...  app.env
# owner=root, group=analyst, mode=400 (仅所有者可读)
# analyst 作为 group 成员可以读取这个文件！
```

**关键发现**：
```
文件：/opt/backups/app.env
权限：400 (rw-------)
所有者：root:analyst

analyst 用户通过组成员身份可以读取该文件：
内容可能包含：db_password=TrainingOnly-DoNotReuse
```

### 步骤 5：执行 sudo 命令并分析结果

```bash
# 执行特权命令（不需要密码）
sudo /usr/local/bin/backup-app

# 检查备份文件是否生成
ls -la /tmp/app-backup.tgz

# 如果能访问备份文件，说明存在信息泄露风险
tar -tzf /tmp/app-backup.tgz 2>/dev/null || echo "无法访问备份内容"
```

### 步骤 6：完整的权限审计

```bash
# 检查 /proc 访问（可能泄露其他进程信息）
ls -la /proc/

# 检查敏感文件权限
ls -la /etc/shadow 2>/dev/null || echo "无法访问 shadow 文件"
ls -la /etc/passwd

# 检查 SUID/SGID 文件（提权常用路径）
find / -perm -4000 -o -perm -2000 2>/dev/null | head -20

# 检查 SSH 密钥
ls -la ~/.ssh/ 2>/dev/null || echo "无 SSH 目录"
```

**记录所有发现**：
```
1. sudo 规则：analyst ALL=(root) NOPASSWD: /usr/local/bin/backup-app
2. backup-app 行为：tar -czf /tmp/app-backup.tgz /opt/app
3. 敏感文件：/opt/backups/app.env (mode 640, owner root:analyst)
4. 可利用方式：analyst 通过 sudo 执行 backup-app，以 root 身份 tar 打包 /opt/app
5. 信息泄露风险：analyst 可读取包含密码的 app.env
```

## 技术原理

### Linux 权限模型

```
用户身份：
  UID=0 (root)     → 最高权限，可以做任何事
  UID=1001 (analyst) → 普通用户，权限受限

权限检查流程：
  用户访问文件 → 检查 UID/GID → 比较文件权限 → 决定是否允许

权限位：
  rwx (421) = 7
  rw- (420) = 6
  r-- (400) = 4

特殊权限位：
  SUID (4000) → 以文件所有者身份执行
  SGID (2000) → 以文件所属组身份执行
  Sticky (1000) → 目录中仅所有者可删除文件
```

### sudo 工作原理

```
1. 用户执行 sudo command
2. sudo 检查 /etc/sudoers 规则
3. 如果匹配且无 NOPASSWD，提示输入密码
4. 如果匹配且有 NOPASSWD，直接执行
5. 以指定用户（默认 root）身份运行命令
```

### /etc/sudoers 配置语法

```
user  host=(runas)  NOPASSWD:  command
 │      │       │         │         │
 │      │       │         │         └── 可执行的命令（绝对路径）
 │      │       │         └────────── 无需密码（NOPASSWD:）
 │      │       └──────────────────── 以什么用户身份运行（默认 root）
 │      └──────────────────────────── 从哪些主机连接（ALL=任何）
 └───────────────────────────────── 哪个用户（可以是组 %groupname）
```

### 本实验的安全问题

```
问题 1：NOPASSWD 允许自动化提权

风险场景：
1. 攻击者获得 analyst 账户
2. 执行 sudo /usr/local/bin/backup-app（不需要密码）
3. 命令以 root 身份执行
4. 攻击者实现权限提升

问题 2：backup-app 内容不安全

backup-app 执行：
/bin/tar -czf /tmp/app-backup.tgz /opt/app

潜在问题：
- tar 支持 --exclude、--listed-incremental 等危险选项
- /tmp 目录通常可写（如果 /tmp 有 sticky bit 防护则更安全）
- 如果攻击者能替换 tar 或修改 /opt/app 内容，可能利用
```

## 防御方案

### 1. 最小化 sudo 规则

```bash
# ❌ 危险配置
analyst ALL=(ALL) NOPASSWD: ALL              # 太宽
analyst ALL=(root) NOPASSWD: /usr/bin/less   # less 可执行 shell

# ✅ 安全配置
analyst ALL=(backup-service) NOPASSWD: /usr/local/bin/backup-app
# → 以非 root 用户运行，降低风险

# 或者使用 tag 精确控制
analyst ALL=(root) NOPASSWD: /usr/local/bin/backup-app, \
                  CWD=/opt/app, \
                  RUNAS=root
```

### 2. 文件权限最小化

```bash
# 敏感文件：640 或 600
chmod 640 /opt/backups/app.env
# owner=root, group=analyst
# others=0（无权限）

# 确保 backup-app 目录不可被普通用户修改
chmod 700 /usr/local/bin/backup-app
```

### 3. 安全的 backup-app 实现

```bash
# ✅ 安全版本（使用绝对路径，不允许参数）
#!/bin/sh
# 验证自身完整性
if [ -f /usr/bin/tar ] && [ /usr/bin/tar -ef /usr/bin/tar > /dev/null 2>&1 ]; then
    /bin/tar -czf /tmp/app-backup.tgz /opt/app --warning=no-file-changed
fi
# --warning=no-file-changed 避免警告输出
# 不使用任何用户可控的参数
```

### 4. 审计检查清单

```bash
# 每季度执行一次权限审计
# 检查 SUID/SGID 文件
find / -perm -4000 -o -perm -2000 2>/dev/null

# 检查 NOPASSWD 规则
sudo -l | grep NOPASSWD

# 检查弱权限文件
find /opt -perm -o+w -type f 2>/dev/null

# 检查无主文件（可能被攻击者利用）
find / -nouser -o -nogroup 2>/dev/null
```

## 思考题

### 思考题 1：为什么 NOPASSWD 本身就是一个风险？

**场景**：analyst 账户的密码是 `Analyst123`（已经很复杂了）。

**问题**：
1. 攻击者通过键盘记录或钓鱼获得 analyst 的密码后，能做什么？
2. 如果改成需要密码验证的 sudo，分析攻击者需要什么才能提权？
3. NOPASSWD 的使用场景有哪些？哪些情况下 NOPASSWD 实际上是合理的？

### 思考题 2：tar 命令的潜在危险

**问题**：
1. `tar` 支持 `--exclude` 选项，攻击者是否可以利用这个选项绕过某些文件访问限制？
2. `tar` 的 `--listed-incremental` 选项如果被利用，会造成什么后果？
3. 为什么说 `tar` 配合 root 权限本身就是危险的组合？（提示：考虑符号链接攻击）

### 思考题 3：如何设计真正安全的备份脚本

**假设**：你需要为普通用户设计一个备份 `/opt/app` 目录的工具，同时确保：
- 备份内容不会泄露敏感文件
- 备份脚本本身不能被利用提权
- 备份文件只能被授权用户读取

**请提出至少 3 个层面的安全措施**（身份验证、权限控制、备份内容过滤等）。

### 思考题 4：sudo 规则审查的方法论

**场景**：你接手了一个有 100 个用户的服务器，需要审查所有 sudo 规则。

**问题**：
1. 如何快速识别出危险的 sudo 规则（优先级排序）？
2. 什么样的规则算是"过宽"？给出具体定义。
3. 如果发现一个规则是历史遗留，无法确认是否存在真实业务需求，你通常怎么处理？

## 交付物

1. **身份确认截图** — `id` 命令输出
2. **sudo 规则分析** — `sudo -l` 输出及安全分析
3. **文件权限审计报告** — `/opt` 目录结构和敏感文件
4. **提权路径说明** — 攻击者如何利用当前配置提权
5. **防御方案清单** — 针对每项发现的具体加固措施
6. **思考题答案**

## 工具速查

```bash
# 身份信息
id                        # UID、GID、所属组
whoami                    # 当前用户名
groups                    # 所属组列表

# 权限检查
ls -la /path/to/file      # 详细文件信息
stat /path/to/file        # 更详细的元数据

# sudo 审计
sudo -l                   # 当前用户可执行的 sudo 命令
sudo -l -U username       # 查看指定用户的 sudo 权限

# 特殊权限文件
find / -perm -4000 -o -perm -2000 2>/dev/null

# 日志分析（如果可用）
cat /var/log/auth.log 2>/dev/null | grep sudo
journalctl -u sudo 2>/dev/null
```