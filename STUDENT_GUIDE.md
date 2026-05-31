# Cyber Practice 学生使用教程

本教程面向已经拿到 Kali 虚拟机或需要自己配置 Kali 虚拟机的同学。

所有实验都在本机 `127.0.0.1` 和 Docker 容器中完成。不要扫描校园网、同学电脑或互联网主机。

## 一、你拿到的是哪一种环境

### 情况 A：老师已经发了完整 VM 镜像

如果老师发的是已经配置好的虚拟机，启动 Kali 后直接进入实验系统：

```bash
cd ~/cyber-practice
./student.sh
```

如果老师通知需要更新实验系统，按“二、更新已有实验系统”操作。

### 情况 B：你只有一个全新的 Kali VM

如果你的 Kali 里还没有 `~/cyber-practice` 目录，需要先运行一键配置脚本，按“三、全新 Kali 一键配置”操作。

## 二、更新已有实验系统

进入实验目录：

```bash
cd ~/cyber-practice
```

如果目录里已经有更新脚本：

```bash
./update-system.sh
```

如果旧镜像里还没有 `update-system.sh`，先下载一次：

```bash
curl -LO https://raw.githubusercontent.com/ZolaNUAA/cyber-practice/main/update-system.sh
chmod +x update-system.sh
./update-system.sh
```

更新脚本会更新：

- `student.sh`
- 实验引导脚本和课程内容
- `labs/`、`lib/`、`services/`
- Docker Compose 配置
- 预置证据文件和检查脚本

更新脚本会保留：

- 你的实验进度 `.progress/`
- 提交文件 `submit/`
- 报告和截图 `reports/`
- 抓包文件 `pcaps/`
- 本地日志和证据目录

如果课堂时间紧，只想先更新课程和脚本，不重建 Docker 镜像：

```bash
./update-system.sh --skip-docker
```

更新完成后检查环境：

```bash
./check-env.sh
```

## 三、全新 Kali 一键配置

把 `setup-lab-vm.sh` 下载到 Kali 中任意目录，例如 `~/Downloads`。然后运行：

```bash
chmod +x setup-lab-vm.sh
sudo ./setup-lab-vm.sh
```

脚本会自动完成：

- 配置国内下载源
- 安装基础工具和安全工具
- 安装 Docker
- 下载完整实验系统到 `~/cyber-practice`
- 拉取和构建实验靶机
- 验证 12 个实验环境

配置完成后进入实验目录：

```bash
cd ~/cyber-practice
./student.sh
```

如果 Docker 提示权限问题，先退出 Kali 重新登录。也可以执行：

```bash
newgrp docker
```

## 四、进入实验系统

每次上课前进入实验系统：

```bash
cd ~/cyber-practice
./student.sh
```

第一次运行会要求输入姓名。姓名会用于生成提交文件。

主界面中常用操作：

- 按 `Enter`：继续当前实验
- 输入实验编号，例如 `1` 或 `lab01`：进入对应实验
- 输入 `r`：刷新主界面
- 输入 `q`：退出

实验步骤界面中常用操作：

- 按 `Enter`：进入下一步
- 输入 `h`：查看提示
- 输入 `b`：返回上一步
- 输入 `r`：从第一步重新查看本实验
- 输入 `q`：退出并保存进度

已经完成的实验也可以重新进入回看，不会清空你的进度。

## 五、启动和重置单个实验

一般情况下不需要手动启动实验，`student.sh` 会引导你完成。

如果老师要求手动启动某个实验：

```bash
cd ~/cyber-practice
./start-lab.sh lab04
```

如果实验环境异常，可以重置当前实验：

```bash
./reset-lab.sh lab04
```

停止所有实验容器：

```bash
./stop-lab.sh
```

## 六、提交实验结果

每个实验完成后，查看该实验教程中的“交付物”要求。

`./student.sh` 每个步骤中显示的“过程自检”只用于确认当前步骤是否完成，不是最终报告的思考题。最终需要回答哪些思考题，以对应实验的 `tutorial/TUTORIAL.md` 中“思考题”章节为准。

通常需要提交：

- 实验报告
- 命令输出或截图
- 抓包文件
- 日志或证据分析结果
- 思考题答案

建议把提交材料放到：

```bash
~/cyber-practice/submit/
```

如果老师指定了 QQ 群、学习平台或其它提交方式，以老师要求为准。

## 七、常见问题

### 1. 提示 Docker 权限不足

先退出 Kali 重新登录，再运行：

```bash
cd ~/cyber-practice
./check-env.sh
```

也可以临时执行：

```bash
newgrp docker
```

### 2. 某个端口打不开

先确认实验是否已经启动：

```bash
cd ~/cyber-practice
./start-lab.sh lab01
```

再检查环境：

```bash
./check-env.sh
```

### 3. 更新时网络慢或失败

稍后重试：

```bash
cd ~/cyber-practice
./update-system.sh
```

如果只是课堂材料急需更新，可以先跳过 Docker：

```bash
./update-system.sh --skip-docker
```

### 4. 不小心退出了实验

重新进入即可：

```bash
cd ~/cyber-practice
./student.sh
```

进度会自动保存。

## 八、安全边界

本课程所有实验只允许在本机 Kali VM 内进行。

允许：

- 扫描 `127.0.0.1`
- 使用 `localhost` 或课程 Docker 容器的本地端口
- 访问本地端口，例如 `8082`、`8086`、`3000`
- 分析本地日志、抓包和 Docker 靶机

禁止：

- 扫描校园网
- 扫描同学电脑
- 扫描公网 IP 或真实网站
- 把课程 payload 用到真实系统
- 把教程命令中的 `127.0.0.1` 替换成外部 IP、域名或网段

命令示例：

```bash
# 正确：只扫描本地课程靶机
nmap -sV -p 8082 127.0.0.1
curl http://127.0.0.1:8082/backup/

# 错误：这些都不属于课程授权范围
nmap -sV 192.168.0.0/24
nmap example.com
sqlmap -u "https://真实网站/search?q=1"
```

如果不确定某个目标是否属于实验范围，默认不要执行，先询问老师。
