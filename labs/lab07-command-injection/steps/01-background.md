# TITLE: 背景 — 命令注入原理
# STEP: 1
# MINUTES: 8

### WHY

命令注入（Command Injection）发生在应用将用户输入传递给系统 Shell 时。

**典型场景**：一个网站让你输入 IP 地址来 Ping 测试。后端代码可能是：
```python
cmd = f"ping -c 1 {user_input}"
subprocess.run(cmd, shell=True)
```

如果用户输入 `127.0.0.1; id`，实际执行的命令变为：
```
ping -c 1 127.0.0.1; id
```

`;` 是 Shell 命令分隔符，`id` 命令也会被执行！

**命令分隔符**：
- `;` — 顺序执行（Linux/Windows）
- `&&` — 前一个成功后执行
- `||` — 前一个失败后执行
- `|` — 管道
- `` ` `` — 命令替换（反引号）
- `$()` — 命令替换

### DO

本步骤不需要操作。理解命令注入的原理。

### CHECK

你能解释 `shell=True` 为什么危险吗？
