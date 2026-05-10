# TITLE: 环境 — 访问 Nginx 教学网站
# STEP: 2
# MINUTES: 5

### WHY

本实验使用一个故意配置了目录浏览的 Nginx 服务器。运行在 Docker 容器中，端口 127.0.0.1:8082。

### DO

1. 启动实验：
```
cd ~/cyber-practice
./reset-lab.sh lab02
```

2. 浏览器访问：http://127.0.0.1:8082

3. 用 curl 查看页面：
```
curl http://127.0.0.1:8082/
```

### CHECK

页面有哪些链接？有没有不寻常的路径？
