# TITLE: 防御 — 输入过滤 vs 输出编码
# STEP: 6
# MINUTES: 12

### WHY

XSS 防御的核心原则：**永远不要信任用户输入**。

两种互补的防御策略：

1. **输入过滤**：在数据进入系统时清理
   - 移除或转义 `<script>` 标签
   - 白名单验证（如只允许字母数字）
   - 问题：攻击者总能找到绕过方法

2. **输出编码**：在数据输出到页面时转义（更可靠）
   - HTML 实体编码：`<` → `&lt;`
   - JavaScript 编码
   - URL 编码
   - 根据输出上下文选择正确的编码方式

**多层防御**：
- 参数化模板引擎（如 React 的 JSX 自动转义）
- CSP 策略
- Cookie 的 HttpOnly + Secure + SameSite
- 定期安全测试

### DO

撰写实验报告：
```
nano ~/cyber-practice/reports/lab05-report.md
```

包含：
1. XSS 攻击证据（截图）
2. Cookie 属性分析
3. CSP 策略建议
4. 综合防御方案

### CHECK

报告是否包含以上 4 项内容？
