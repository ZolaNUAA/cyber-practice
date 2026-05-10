# TITLE: 正常操作 — 使用 Ping 功能
# STEP: 2
# MINUTES: 5

### WHY

先正常使用，再理解哪里可能被利用。

### DO

1. 启动实验：
```
cd ~/cyber-practice
./reset-lab.sh lab07
```

2. 正常 Ping 操作：
```
curl "http://127.0.0.1:8087/?host=127.0.0.1"
```

3. 观察输出——返回了 Ping 命令的结果

4. 在浏览器中访问 http://127.0.0.1:8087

### CHECK

- Ping 结果正常返回了吗？
- 你看到了什么输出？
