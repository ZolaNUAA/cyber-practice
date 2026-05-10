# TITLE: 背景 — SQL注入是什么
# STEP: 1
# MINUTES: 8

### WHY

SQL注入（SQL Injection）是 OWASP Top 10 中最古老、最危险的 Web 漏洞之一。

**简单来说**：当网站把用户输入的内容直接拼接到 SQL 查询语句中，攻击者就可以"注入"恶意的 SQL 代码，从而绕过登录、窃取数据、甚至删除整个数据库。

**真实案例**：
- 2012年 Yahoo Voices 泄露 45万用户密码 — 攻击者通过 SQL注入获取
- 2015年 TalkTalk 被攻击，15万用户数据泄露，公司被罚 40万英镑
- 2021年 某教育平台 700万学生信息泄露 — SQL注入至今仍在发生

**它是怎么工作的？**

想象一个登录查询：
\`\`\`
SELECT * FROM users WHERE username='输入的用户名' AND password='输入的密码'
\`\`\`

如果你输入用户名 `admin' --`，查询变成：
\`\`\`
SELECT * FROM users WHERE username='admin' --' AND password='whatever'
\`\`\`

`--` 是 SQL 注释符，后面的密码检查被注释掉了——你不需要密码就能登录！

**本实验中你会**：
- 在安全的本地环境中体验真实的 SQL 注入攻击
- 理解为什么参数化查询是防线核心
- 学会如何给开发团队写修复建议

### DO

本步骤不需要操作。认真阅读上述原理，理解后再继续。

### CHECK

你能用自己的话解释吗？
- SQL注入的根本原因是什么？
- `' OR 1=1 --` 这个 payload 为什么危险？

想清楚后按 Enter 进入下一步。
