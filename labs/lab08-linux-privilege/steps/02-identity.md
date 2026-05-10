# TITLE: 身份审查 — 当前用户与组
# STEP: 2
# MINUTES: 8

### WHY

进入系统后的第一件事：弄清楚你是谁、你能做什么。

### DO

1. 启动实验：
```
cd ~/cyber-practice
./reset-lab.sh lab08
docker exec -it priv-lab bash
```

你现在是 `analyst` 用户。

2. 检查当前身份：
```
id
whoami
groups
```

3. 查看你能看到的用户信息：
```
cat /etc/passwd
```

4. 查看家目录：
```
ls -la ~
cat ~/README.txt
```

### CHECK

- 当前用户是 `analyst` 吗？
- 这个用户属于哪些组？
