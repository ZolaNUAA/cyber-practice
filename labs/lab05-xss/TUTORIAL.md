# Lab05：XSS 与会话安全

## 学习目标

1. 理解 XSS 的三种类型（反射型、存储型、DOM 型）及其区别
2. 掌握 Cookie 安全属性（HttpOnly、Secure、SameSite）的作用
3. 学会使用 CSP（内容安全策略）防御 XSS
4. 理解输出编码的原理和正确实现

## 预备知识

### XSS 的历史

- **1999 年**：XSS 首次被记录，最初叫 CSS（Cross-Site Scripting）
- **2000 年**：为避免与 CSS 层叠样式表混淆，正式改名 XSS
- **2011 年**：Netflix XSS 攻击，攻击者在评论区注入脚本，窃取数千个用户会话
- **至今**：OWASP Top 10 几乎每期都榜上有名

### 三种 XSS 类型对比

| 类型 | 触发方式 | 持久性 | 风险等级 | 攻击难度 |
|------|---------|--------|---------|---------|
| **反射型** | URL 参数直接反射到页面 | 非持久 | 中 | 低（一次性） |
| **存储型** | 恶意脚本存入数据库 | **永久** | **极高** | 中（需要找到存储点） |
| **DOM 型** | JavaScript 处理 URL 时触发 | 非持久 | 中 | 高（前端代码审计） |

### XSS 本质：用户输入被当作代码执行

```html
<!-- 服务器代码（PHP/JSP/Python） -->
<p>搜索结果: <?php echo $_GET['q']; ?></p>
<!-- URL: /search?q=<script>alert(1)</script> -->

<!-- 浏览器收到的 HTML -->
<p>搜索结果: <script>alert(1)</script></p>
<!--                    ↑ 浏览器把 <script> 标签当作代码执行 -->
```

## 实验环境

```bash
./student.sh  # 选择对应的实验开始
```

### 目标靶场

- **Juice Shop**：`http://127.0.0.1:3000` — XSS 靶场
- **WebGoat**：`http://127.0.0.1:8080/WebGoat` — OWASP 官方靶场

## 操作步骤

### 步骤 1：在 Juice Shop 中寻找 XSS 注入点

#### 1.1 寻找输入点

```bash
# Juice Shop 搜索功能（常见的 XSS 注入点）
curl -s "http://127.0.0.1:3000/rest/products/search?q=apple"

# 搜索框输入 ' 进行测试（观察是否被转义）
curl -s "http://127.0.0.1:3000/rest/products/search?q='"
```

**观察要点**：
- 搜索结果中是否出现单引号 `'`
- 如果单引号出现，说明可能没有 HTML 转义（XSS 风险）
- 如果单引号变成 `&#x27;` 或 `&apos;`，说明有 HTML 编码

#### 1.2 反射型 XSS 测试

```bash
# 在浏览器地址栏输入（或用 curl）：
# http://127.0.0.1:3000/#/search?search=<script>alert(document.cookie)</script>

# 用 curl 测试（查看 HTML 响应）
curl -s "http://127.0.0.1:3000/" | grep -o "<script>.*</script>" || echo "No script tag found in response"
```

**关键观察**：XSS 在本实验中需要浏览器执行，因为 Juice Shop 是 SPA（单页应用），服务器返回的 HTML 是框架代码，实际内容由 JavaScript 渲染。

#### 1.3 在浏览器中完成 WebGoat XSS 课程

```bash
firefox http://127.0.0.1:8080/WebGoat
```

完成以下课程：
- **Cross-Site Scripting (XSS)** → 反射型 XSS
- **Cross-Site Scripting (XSS)** → 存储型 XSS
- **Cross-Site Scripting (XSS)** → DOM 型 XSS

**记录每个课程的 payload 和成功标志**：

| 课程 | Payload | 成功标志（页面显示） |
|------|---------|---------------------|
| 反射型 | `<script>alert('XSS')</script>` | 弹出 alert |
| 存储型 | `<img src=x onerror=alert(1)>` | 刷新页面后弹出 |
| DOM 型 | `javascript:alert(document.domain)` | 地址栏执行 |

### 步骤 2：Cookie 安全属性分析

#### 2.1 检查 Juice Shop 的 Cookie

```bash
# 用浏览器开发者工具或 curl 查看 Set-Cookie 头
curl -s -D - http://127.0.0.1:3000/ -o /dev/null | grep -i "set-cookie"

# 或者在浏览器 Console 中执行
# document.cookie  → 查看当前 cookie
```

**你应该观察的 Cookie 属性**：
- `HttpOnly` — 是否有？（防止 JavaScript 读取）
- `Secure` — 是否有？（仅 HTTPS 传输）
- `SameSite` — 是 Strict/Lax/None？（防止 CSRF）
- `Path` — 作用范围
- `Max-Age` 或 `Expires` — 过期时间

**示例**：
```
Set-Cookie: token=eyJhbGc...; HttpOnly; Secure; SameSite=Lax; Path=/
```

#### 2.2 分析缺失的安全属性

如果 Cookie 缺少某个属性，分析其风险：

| 属性缺失 | 风险 |
|---------|------|
| 无 HttpOnly | XSS 攻击者可窃取 Cookie（`document.cookie`） |
| 无 Secure | HTTPS 降级攻击可窃取 Cookie |
| 无 SameSite | CSRF 攻击可在用户不知情时发送 Cookie |
| 无 Max-Age | Session 永不过期，攻击者有更长的时间窗口 |

### 步骤 3：输出编码实验

#### 3.1 观察浏览器对特殊字符的处理

在浏览器 Console 中测试：

```javascript
// 输入（作为搜索词）：
// <script>alert(1)</script>

// 查看页面源码（右键 → View Page Source）
// 搜索结果中这个字符串是否被转义？

// 用 JavaScript 获取元素内容：
document.querySelector('.search-result').innerHTML
// vs.
document.querySelector('.search-result').textContent
```

**观察**：
- `innerHTML` 会解析 HTML 标签（危险）
- `textContent` 会把输入当作文本（安全）

#### 3.2 XSS payload 练习

在不同输入点测试以下 payload：

```html
<!-- 经典 script 注入 -->
<script>alert(document.cookie)</script>

<!-- 事件处理器注入 -->
<img src=x onerror="alert('XSS')">

<!-- SVG 注入 -->
<svg onload="alert(document.domain)">

<!-- URL 编码绕过 -->
<img src="x" onerror="alert('XSS')">

<!-- 大小写混合绕过 -->
<ScRiPt>alert(1)</sCrIpT>
```

**测试位置**：
1. 搜索框
2. 评论/反馈表单
3. URL 路径（如 `/#/search/<script>alert(1)</script>`）
4. 用户资料页面

### 步骤 4：防御措施验证

#### 4.1 HttpOnly Cookie 验证

```bash
# 尝试用 JavaScript 读取 HttpOnly Cookie（浏览器 Console）
# document.cookie  → 如果有 HttpOnly，这行代码不会显示该 cookie

# 对比：没有 HttpOnly 的 cookie 会被显示
# 有 HttpOnly 的 cookie 不显示（但仍然会在请求中发送）
```

#### 4.2 CSP 头检查

```bash
# 检查服务器是否发送 CSP 头
curl -s -I http://127.0.0.1:3000/ | grep -i "content-security-policy"
curl -s -I http://127.0.0.1:8082/ | grep -i "content-security-policy"
```

**常见 CSP 配置**：

```http
# 严格 CSP（禁止内联脚本）
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'

# 宽松 CSP（允许同域脚本 + nonce）
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-abc123'

# 无 CSP（无保护）
X-Frame-Options: ??? （缺失）
```

## 技术原理

### XSS 攻击链

```
┌─────────────────────────────────────────────────────────────┐
│ 反射型 XSS 攻击链                                            │
│                                                              │
│ 攻击者 ──▶ 邮件/帖子 ──▶ 受害者点击链接 ──▶ 浏览器执行脚本 ──▶ │
│               URL: http://site.com/search?q=<script>...      │
│                           │                                  │
│                           ▼                                  │
│                    脚本窃取 Cookie ──▶ 发送到攻击者服务器     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 存储型 XSS 攻击链                                            │
│                                                              │
│ 攻击者 ──▶ 在评论区发布 ──▶ 脚本存入数据库 ──▶ 所有访问者 ──▶ │
│           <script>...</script>              │              │
│                                  用户 A ──▶ 执行脚本        │
│                                  用户 B ──▶ 执行脚本        │
└─────────────────────────────────────────────────────────────┘
```

### HttpOnly Cookie 的工作原理

```
没有 HttpOnly 时：

浏览器 ◀── Set-Cookie: session=abc123
JavaScript：document.cookie
  ↓
输出：session=abc123（攻击者可读取）

有 HttpOnly 时：

浏览器 ◀── Set-Cookie: session=abc123; HttpOnly
JavaScript：document.cookie
  ↓
输出：（空白，HttpOnly Cookie 不可被 JS 读取）
但是：浏览器在发送 HTTP 请求时仍会自动携带该 Cookie
```

**结论**：HttpOnly 不能防止 XSS 攻击成功，只能防止攻击者通过 XSS 窃取 Cookie。

### CSP 内容安全策略

```
HTTP Response:
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-random123'

效果：
1. 禁止从外部域名加载脚本（防止 CDN 劫持）
2. 禁止内联脚本 <script>...</script>（防止 XSS 注入）
3. 仅允许带有正确 nonce 的内联脚本执行
```

**绕过 CSP 的常见方式**：
- JSONP 端点（`<script src="https://api.twitter.com/callback=alert(1)">`）
- `eval()` 和 `new Function()`（执行字符串代码）
- 第三方 CDN 被黑

## 防御方案

### 1. 输出编码（Output Encoding）

```javascript
// ❌ 危险：innerHTML 直接插入用户输入
element.innerHTML = userInput;

// ✅ 安全 1：textContent
element.textContent = userInput;

// ✅ 安全 2：手动转义 HTML 特殊字符
function escapeHTML(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;');
}
element.innerHTML = escapeHTML(userInput);
```

### 2. Cookie 安全属性

```http
Set-Cookie: session=abc123; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=3600
```

### 3. CSP 配置

```apache
# Apache httpd.conf 或 .htaccess
Header set Content-Security-Policy "default-src 'self'; script-src 'self' 'nonce-% nonce %'; object-src 'none'; base-uri 'self';"
```

```nginx
# Nginx 配置
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'nonce-random123'; object-src 'none';" always;
```

### 4. 输入验证

```javascript
// 严格白名单（仅允许字母数字）
function sanitizeInput(input) {
  return input.replace(/[^a-zA-Z0-9]/g, '');
}

// 宽松白名单（允许部分特殊字符）
function sanitizeRichInput(input) {
  return input
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}
```

## 思考题

### 思考题 1：HttpOnly Cookie 能防止 XSS 攻击吗？

**问题**：如果网站设置了 `HttpOnly` Cookie，攻击者是否还能利用 XSS 漏洞做其他事情？

**扩展**：即使无法直接读取 Cookie，攻击者还能：
1. 通过 XSS 做什么？（至少列举 3 种）
2. 窃取用户数据除了 Cookie 外还有什么方式？

### 思考题 2：CSP 的 nonce 模式 vs. hash 模式

CSP 的内联脚本控制有两种方式：

```http
<!-- nonce 模式 -->
Content-Security-Policy: script-src 'self' 'nonce-abc123'
<!-- 服务器为每个请求生成随机 nonce，内联脚本必须匹配 -->
<script nonce="abc123">alert(1)</script>

<!-- hash 模式 -->
Content-Security-Policy: script-src 'self' 'sha256-abc123...'
<!-- 脚本内容 hash 必须匹配 -->
<script>alert(1)</script>  <!-- hash of this script must be pre-calculated -->
```

**问题**：
1. 为什么 CSP 要禁止内联脚本？内联脚本有哪些危险？
2. nonce 和 hash 哪个更难被攻击者绕过？（提示：攻击者能否控制 nonce？hash 是基于什么的？）
3. CSP 能完全替代输出编码吗？为什么？

### 思考题 3：SameSite Cookie 的局限性

SameSite=Lax 在以下情况仍然会发送 Cookie：
- 用户通过链接导航（`<a href="...">`）
- 浏览器发送 GET 请求

**问题**：
1. SameSite 能完全防止 CSRF 攻击吗？什么情况下攻击者可以绕过？
2. SameSite=Strict 会不会影响用户体验？举一个正常场景被阻止的例子。
3. 为什么现代浏览器默认 SameSite=Lax，但仍建议开发者显式设置？

### 思考题 4：存储型 XSS 的检测与防御成本

**场景**：你发现公司产品的评论区存在存储型 XSS（攻击者发布的评论含恶意脚本，访问该评论的所有用户都会被攻击）。

**问题**：
1. 作为防御者，为什么存储型 XSS 比反射型 XSS 更难发现？（提示：考虑"谁会触发"）
2. 修复这个漏洞需要涉及哪些系统？（前端、后端、数据库）
3. 如果临时无法修改代码，有什么紧急缓解措施？

## 交付物

1. **WebGoat XSS 课程截图** — 完成 3 种 XSS 类型各 1 个课程
2. **Cookie 安全属性分析报告** — 检查 Juice Shop 的 Cookie 缺少哪些属性
3. **XSS payload 列表** — 至少 5 个有效的 XSS 测试 payload
4. **CSP 头分析** — 检查目标服务是否配置了 CSP
5. **防御方案代码** — 输出编码实现 + Cookie 安全属性配置
6. **思考题答案**

## 工具速查

```bash
# 检查 Cookie 头
curl -s -I http://127.0.0.1:3000/ | grep -i set-cookie
curl -s -I http://127.0.0.1:8082/ | grep -i set-cookie

# XSS 常用测试 payload
<script>alert(document.cookie)</script>
<img src=x onerror=alert(1)>
<svg onload=alert(1)>
javascript:alert(document.domain)
<body onload=alert(1)>

# 自动化 XSS 扫描（请勿在生产环境使用）
# XSStrike 是常用的 Python XSS 扫描工具
```