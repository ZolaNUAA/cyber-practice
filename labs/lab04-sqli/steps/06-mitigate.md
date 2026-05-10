# TITLE: 防御 — 如何修复和预防
# STEP: 6
# MINUTES: 10

### WHY

知道漏洞怎么产生，就知道怎么修复。SQL注入的防御有一个"银弹"。

**第一道防线：参数化查询（Prepared Statements）**

参数化查询将 SQL 结构（指令）和用户数据（参数）**完全分离**。数据库永远不会把参数当作 SQL 代码执行。

\`\`\`
# 安全的写法
username = request.form['username']
password = request.form['password']
query = "SELECT * FROM users WHERE username=? AND password=?"
cursor.execute(query, (username, password))
\`\`\`

**为什么安全？** 即使 `username` 是 `admin' --`，数据库也只把它当作一个普通字符串值，不会当作 SQL 指令。

**完整的防御层次**（纵深防御）：

1. **参数化查询** — 最核心，第一道防线
2. **输入验证** — 白名单验证，拒绝明显恶意的输入
3. **最小权限数据库账户** — 应用只用 readonly 账户，限制损害范围
4. **通用错误信息** — 不暴露数据库结构给攻击者
5. **Web 应用防火墙 (WAF)** — 检测并拦截 SQL 注入 payload
6. **定期安全测试** — 自动化扫描 + 渗透测试

### DO

阅读上面的防御层次。思考一下你自己的项目或见过的网站：
- 它们可能缺少哪些防御措施？
- 如果让你给一个团队写邮件建议修复 SQL 注入，你会怎么写？

### CHECK

- 你能解释"参数化查询"为什么能防止 SQL 注入吗？
- 为什么说"转义特殊字符"不是可靠的防御方案？
- 准备好为下一步撰写你的修复建议。
