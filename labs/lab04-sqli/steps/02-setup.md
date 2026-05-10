# TITLE: 启动靶机 — 准备实验环境
# STEP: 2
# MINUTES: 5

### WHY

SQL注入攻击需要一个运行着数据库的 Web 应用作为目标。

本实验使用两个业界知名的教学靶场：
- **Juice Shop** (http://127.0.0.1:3000)：OWASP 官方出品的"不安全果汁店"，包含大量真实漏洞
- **WebGoat** (http://127.0.0.1:8080/WebGoat)：OWASP 出品的 Web 安全教学平台，有专门的 SQL 注入课程

它们都在你本地 Docker 中运行，**完全隔离，不会影响外部网络**。

### DO

打开一个**新终端**，执行以下命令启动实验环境：

\`\`\`
cd ~/cyber-practice
./start-lab.sh lab04
\`\`\`

等待容器下载/启动完成（首次可能需几分钟），然后浏览器访问：

- http://127.0.0.1:3000 — Juice Shop
- http://127.0.0.1:8080/WebGoat — WebGoat

### CHECK

在终端执行验证命令：

\`\`\`
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000
\`\`\`

如果输出 `200`，说明 Juice Shop 运行正常。

如果输出 `000`，请检查：
1. 是否执行了 `./start-lab.sh lab04`
2. 容器是否仍在下载/构建中（`docker ps` 查看）
