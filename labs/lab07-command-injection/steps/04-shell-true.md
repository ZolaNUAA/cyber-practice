# TITLE: 原理 — shell=True 风险分析
# STEP: 4
# MINUTES: 10

### WHY

命令注入的根本原因：**将数据和指令混在一起**。

- 数据：用户输入的 IP 地址
- 指令：`ping -c 1`

当使用 `shell=True` 时，Python 把整个字符串传给 `/bin/sh -c`。Shell 会解析其中的特殊字符（`;`, `&&`, `|`），导致注入。

**正确做法**：使用参数数组，不用 Shell：
```python
# 安全！参数以列表形式传递，不经过 Shell
subprocess.run(["ping", "-c", "1", target])
```

### DO

1. 查看 cmd-lab 的源码来理解漏洞：
```
cat services/cmd-lab/app.py
```

2. 找一找第 10 行：`shell=True`

3. 对比安全和不安全的写法

### CHECK

- 源码中哪个参数是关键漏洞点？
- 如果改成 `shell=False`，注入还能成功吗？
