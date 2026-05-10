# TITLE: 连接 — SSH 弱密码登录
# STEP: 2
# MINUTES: 8

### WHY

SSH（Secure Shell）是 Linux 远程管理的事实标准。但它的安全性取决于：
1. 密码强度
2. 是否禁用了 root 登录
3. 是否启用了密钥认证

本实验中的 SSH 容器预设了一个弱密码账户 `student/Student123`——这模拟了真实环境中最常见的配置错误。

### DO

1. 启动实验：
```
cd ~/cyber-practice
./reset-lab.sh lab03
```

2. SSH 连接到目标：
```
ssh student@127.0.0.1 -p 2222
```
密码：`Student123`

3. 登录后查看当前用户信息：
```
id
whoami
hostname
```

4. 退出 SSH：
```
exit
```

### CHECK

- 成功登录了吗？
- 你觉得 `Student123` 这个密码安全吗？为什么？
