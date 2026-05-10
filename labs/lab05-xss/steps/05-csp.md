# TITLE: CSP — 内容安全策略
# STEP: 5
# MINUTES: 10

### WHY

CSP（Content Security Policy）是防御 XSS 的最后一道防线。它通过 HTTP 响应头告诉浏览器：只允许加载来自特定来源的资源。

即使攻击者成功注入了 `<script>` 标签，如果 CSP 禁止内联脚本（`script-src 'self'`），注入的代码就不会执行。

**一个严格的 CSP 示例**：
```
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'
```

这条策略告诉浏览器：
- 所有资源只允许来自同源（`'self'`）
- 禁止内联脚本（`<script>alert(1)</script>` 不会执行）
- 禁止内联样式

### DO

1. 查看 Juice Shop 的响应头：
```
curl -I http://127.0.0.1:3000
```

2. 检查是否有 `Content-Security-Policy` 头

3. 如果没有，建议一个适合该网站的 CSP 策略

### CHECK

- 当前的响应头中有 CSP 吗？
- 你自己能写出一个基本的 CSP 策略吗？
