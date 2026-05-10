# TITLE: 分析 — 理解漏洞原理
# STEP: 5
# MINUTES: 10

### WHY

攻击做完了，现在来回答最重要的问题：**这个漏洞为什么存在？**

根本原因：**不可信的用户输入直接拼接到 SQL 查询中**。

以 Python/Flask 为例，有漏洞的代码长这样：

\`\`\`
# 危险！不要这样做！
username = request.form['username']
password = request.form['password']
query = f"SELECT * FROM users WHERE username='{username}' AND password='{password}'"
cursor.execute(query)
\`\`\`

当用户输入 `admin' --` 时，实际执行的 SQL 变成了：

\`\`\`
SELECT * FROM users WHERE username='admin' --' AND password='whatever'
\`\`\`

`--` 后面的全部被当作注释忽略，密码验证被绕过。

**更深层的原因**：
- **字符串拼接**：代码把"数据"和"指令"混在一起
- **缺少输入验证**：没有检查输入是否包含 SQL 特殊字符
- **过度信任用户**：假设用户不会恶意输入

### DO

1. 打开终端，思考一下：如果你是一个开发者，你会怎么修改那段有漏洞的代码？
2. 在脑海中画出数据流：用户输入 → Web 应用 → 数据库查询 → 数据库执行
3. 找出每个环节可能的风险点

### CHECK

你能回答以下问题吗？

1. 为什么 `' OR 1=1 --` 中的 `'` 是关键的？
2. 如果网站把单引号转义了（`\'`），注入还能成功吗？
3. 除了登录绕过，SQL注入还能造成什么危害？
