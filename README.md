# Cyber Practice Local Lab

基于 Kali Linux + Docker 的网络安全教学实验平台，包含 12 个动手实验。

所有靶机绑定在 `127.0.0.1`，**完全本地化，不会影响外部网络**。

## 🚀 一键部署（全新 Kali VM）

```bash
cd ~/cyber-practice
sudo ./setup-lab-vm.sh
```

这会自动完成：
- 安装所有需要的工具（nmap, burpsuite, wireshark, jq 等）
- 安装 Docker 并配置权限
- 拉取所有镜像（nginx, juice-shop, webgoat）
- 构建自定义靶机镜像
- 逐一验证 12 个实验环境

完成后可以制作学生分发镜像：

```bash
sudo ./setup-lab-vm.sh --student-image    # 一步到位
# 或分步:
./make-student-image.sh                   # 单独制作学生镜像
```

## 📦 制作学生 VM 镜像

```bash
# 方式一：部署时一步完成
sudo ./setup-lab-vm.sh --student-image

# 方式二：单独运行（部署完成后）
./make-student-image.sh
```

学生镜像发布步骤：
1. VirtualBox 中关闭 VM
2. 拍摄快照 `baseline-ready`
3. 文件 → 导出虚拟电脑 → OVA 格式
4. 将 OVA 分发给学生

## 👨‍🎓 学生使用

学生导入 OVA 后：

```bash
cd ~/cyber-practice
./student.sh
```

学生看到进度仪表盘，按 Enter 进入实验，一步一步完成。

## 👨‍🏫 教师使用

```bash
./teacher.sh                          # 管理面板
./teacher.sh --import <提交文件>       # 导入学生提交
./teacher.sh --demo lab04             # 课堂快速演示
./teacher.sh --student               # 以学生身份体验
```

## 🧪 手动启动实验

```bash
./start-lab.sh lab01    # 资产侦察
./start-lab.sh lab04    # SQL注入 → Juice Shop + WebGoat
./start-lab.sh lab09    # 流量分析
./stop-lab.sh           # 停止所有容器
./reset-lab.sh lab04    # 重置实验
./check-env.sh          # 检查环境
```

## 📋 实验列表

| 实验 | 主题 | 步骤 | 靶机端口 |
|------|------|------|----------|
| lab01 | 资产侦察 | 5步 | 8082, 8086, 2222 |
| lab02 | Web信息泄露 | 5步 | 8082 |
| lab03 | 认证审计 | 5步 | 2222 (SSH) |
| lab04 | SQL注入 | 7步 | 3000 (Juice Shop), 8080 (WebGoat) |
| lab05 | XSS与Cookie安全 | 6步 | 3000, 8080 |
| lab06 | 文件上传风险 | 6步 | 8086 |
| lab07 | 命令注入 | 6步 | 8087 |
| lab08 | Linux权限提升 | 5步 | docker exec |
| lab09 | 流量分析 | 6步 | 8089 |
| lab10 | IDS告警分析 | 5步 | evidence/ids/ |
| lab11 | 日志关联 | 6步 | logs/ |
| lab12 | 应急响应 | 9步 | 8092 |

## ⚠️ 重要提醒

- 所有实验活动仅限 `127.0.0.1` 本地环境
- **禁止**扫描校园网、同学机器或互联网主机
- 实验室边界：你的 Kali VM 内部

## 🛠️ 推荐 VM 配置

- CPU: 4 核
- RAM: 8 GB
- 磁盘: 60 GB
- 网络: NAT
