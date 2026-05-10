# TITLE: 正常上传 — 合法文件上传
# STEP: 2
# MINUTES: 5

### WHY

首先理解正常的文件上传流程，再来看哪里可能出问题。

### DO

1. 启动实验：
```
cd ~/cyber-practice
./reset-lab.sh lab06
```

2. 访问 http://127.0.0.1:8086

3. 上传一个普通文本文件：
```
echo "hello world" > /tmp/test.txt
curl -F "file=@/tmp/test.txt" http://127.0.0.1:8086/upload
```

4. 查看上传结果：http://127.0.0.1:8086/uploads

### CHECK

- 文件上传成功了吗？
- 文件保存在哪个路径下？
