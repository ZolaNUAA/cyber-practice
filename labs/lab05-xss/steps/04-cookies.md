# TITLE: Cookie 安全 — 检查缺失的安全属性
# STEP: 4
# MINUTES: 10

### WHY

XSS 攻击的主要目标之一是**窃取用户的 Cookie**——因为 Cookie 中通常包含会话令牌。

Cookie 安全属性可以大幅降低 XSS 的危害：

| 属性 | 作用 |
|------|------|
| **HttpOnly** | JavaScript 无法读取 Cookie，阻止 XSS 窃取 |
| **Secure** | 仅通过 HTTPS 传输 |
| **SameSite** | 限制跨站请求携带 Cookie |
| **__Host-** 前缀 | 强制 Secure + Path=/ |

### DO

1. 打开浏览器开发者工具 (F12)

2. 访问 http://127.0.0.1:3000

3. 查看 Application → Cookies

4. 检查每个 Cookie 的：
   - 是否有 HttpOnly 标记？
   - 是否有 Secure 标记？
   - 是否有 SameSite 属性？

5. 记录缺失的安全属性

### CHECK

- [ ] 找到了几个 Cookie？
- [ ] 哪些 Cookie 缺少 HttpOnly？
- [ ] 如果攻击者通过 XSS 拿到了这些 Cookie，能做什么？
