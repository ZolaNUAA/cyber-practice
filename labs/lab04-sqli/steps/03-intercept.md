# TITLE: 拦截 — 用 Burp Suite 抓取请求
# STEP: 3
# MINUTES: 10

### WHY

SQL注入攻击的第一步是找到"用户输入流向数据库"的地方——通常是登录框、搜索框、URL参数。

Burp Suite 是一个 HTTP 代理工具，它可以拦截浏览器和服务器之间的通信，让你看到完整的请求内容。这对于理解注入点至关重要——你需要知道数据是怎么发送到服务器的，才能构造有效的 payload。

### DO

**启动 Burp Suite**：
\`\`\`
burpsuite &
\`\`\`

**配置浏览器代理**（如果使用 Firefox）：
1. 打开 Firefox → 设置 → 网络设置
2. 选择"手动代理配置"
3. HTTP 代理: `127.0.0.1`，端口: `8080`
4. 勾选"也将此代理用于 HTTPS"
5. 访问 `http://127.0.0.1:3000`

**拦截登录请求**：
1. 在 Burp Suite → Proxy → Intercept 标签页
2. 确保 "Intercept is on"
3. 在 Juice Shop 中点击 "Login"
4. 输入任意用户名和密码（如 `test@test.com` / `test`）
5. 点击登录
6. 回到 Burp Suite —— 你会看到被拦截的 HTTP 请求

观察请求体中的参数。你能找到用户名和密码字段吗？

### CHECK

- 你能否在 Burp Suite 中看到拦截到的 HTTP 请求？
- 请求中包含哪些参数？（如 `email`, `password`）
- 记录这些参数名称，它们就是潜在的注入点。

> 提示：如果不会用 Burp Suite，也可以直接用浏览器开发者工具 (F12) → Network 标签查看请求。
