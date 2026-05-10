### 完整答案

**WebGoat 方案（推荐）**：

1. 访问 http://127.0.0.1:8080/WebGoat
2. 注册并登录
3. 完成 SQL Injection (intro) 课程的第 2-13 关
4. 每关答案：
   - 第 2 关：`SELECT department FROM employees WHERE first_name='Bob' AND last_name='Franco';`
   - 第 3 关：`UPDATE employees SET department='Sales' WHERE first_name='Tobi' AND last_name='Barnett';`
   - 第 4 关：`ALTER TABLE employees ADD COLUMN phone VARCHAR(20);`
   - ...（更多关卡自行探索）

**Juice Shop 方案**：

在登录页，邮箱输入 `' OR 1=1 --`，密码任意。成功登录为管理员。

**核心要点**：
- 输入 `'` 闭合了原本的字符串边界
- `OR 1=1` 让 WHERE 条件变成"永真"
- `--` 注释掉后面的 SQL 代码
- 结果：数据库返回所有用户的第一条记录（通常是管理员）
