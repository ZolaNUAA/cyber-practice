# Lab08：Linux 特权最小化

## 学习目标

1. 理解最小权限原则（Principle of Least Privilege）的核心概念
2. 掌握 Linux 文件权限和所有权的审计方法
3. 学会分析 sudo 规则并评估其安全性
4. 能够提出基于最小权限原则的系统加固方案

## 预备知识

### 最小权限原则的历史

**1975 年**：Saltzer 和 Schroeder 在《Protection and the External of Information》中首次提出
**2017 年 Equifax 事件**：攻击者利用 Apache Struts 漏洞获得 Web 应用权限，而该应用以 root 运行，导致攻击者直接获得系统最高权限

**核心原则**：只授予完成特定任务所需的最小权限，不多也不少。

### sudo 配置错误的典型案例

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