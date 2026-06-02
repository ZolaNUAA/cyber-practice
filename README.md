# Cyber Practice Local Lab

基于 Kali Linux + Docker 的网络安全教学实验平台，包含 12 个动手实验。

默认情况下，所有靶机绑定在 `127.0.0.1`，**完全本地化，不会影响外部网络**。
如果需要从虚拟机外部的宿主机浏览器访问实验服务，可在启动时显式开放到虚拟机网卡：

```bash
LAB_BIND_ADDR=0.0.0.0 ./start-lab.sh lab07
```

只在课堂授权网络中使用该方式，实验目标仍限于本课程靶机。

## 🚀 一键部署（全新 Kali VM）

下载 `setup-lab-vm.sh`，放入 Kali VM，直接运行：

```bash
sudo ./setup-lab-vm.sh
```

首次运行会自动从 GitHub 克隆所有文件，**无需手动 git clone**。
脚本默认使用国内加速源，适合南京/国内校园网：

- Kali apt: `http://mirrors.ustc.edu.cn/kali`
- Docker CE apt: `https://mirrors.aliyun.com/docker-ce/linux/debian`
- Docker Hub registry mirrors: DaoCloud、1ms、dockerproxy

如果不想切换国内源：

```bash
sudo ./setup-lab-vm.sh --no-china-mirrors
```

如需指定学校或单位自己的 Kali 镜像：

```bash
sudo env KALI_MIRROR=http://your.mirror/kali ./setup-lab-vm.sh
```

这会自动完成：
- 自动克隆 GitHub 上的所有实验文件
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

完整学生教程见：[STUDENT_GUIDE.md](STUDENT_GUIDE.md)

学生导入 OVA 后：

```bash
cd ~/cyber-practice
./student.sh
```

学生看到进度仪表盘，按 Enter 进入实验，一步一步完成。

已有镜像更新实验系统：

```bash
cd ~/cyber-practice
./update-system.sh
```

如果旧镜像里还没有 `update-system.sh`，先下载一次：

```bash
cd ~/cyber-practice
curl -LO https://raw.githubusercontent.com/ZolaNUAA/cyber-practice/main/update-system.sh
chmod +x update-system.sh
./update-system.sh
```

只更新脚本和课程文件，不重建 Docker 镜像：

```bash
./update-system.sh --skip-docker
```

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
./verify-lab-env.sh     # 逐个启动并验收 12 个实验环境
```

## 📋 实验列表

| 实验 | 主题 | 步骤 | 靶机端口 |
|------|------|------|----------|
| lab01 | 资产侦察 | 5步 | 8082, 8086, 8089, 3000, 8080, 2222 |
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
- 课程命令中的目标地址不得替换成外部 IP、域名或真实系统
- 正确示例：`nmap -sV -p 8082 127.0.0.1`
- 错误示例：`nmap -sV 192.168.0.0/24`、`nmap example.com`、`sqlmap -u https://真实网站/...`

## 🛠️ 推荐 VM 配置

- CPU: 4 核
- RAM: 8 GB
- 磁盘: 60 GB
- 网络: NAT
