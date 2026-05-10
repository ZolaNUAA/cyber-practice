# TITLE: 抓包 — 用 tcpdump 捕获本地流量
# STEP: 2
# MINUTES: 8

### WHY

tcpdump 是 Linux 下最常用的抓包工具。基本用法：
```
tcpdump -i <接口> -w <文件> <过滤器>
```

由于本实验的 Docker 容器绑定在 127.0.0.1，我们需要捕获回环接口（`lo`）上的流量。

### DO

1. 启动实验：
```
cd ~/cyber-practice
./reset-lab.sh lab09
```

2. 开始抓包（在后台）：
```
sudo tcpdump -i lo -w pcaps/lab09.pcap tcp port 8089 &
```

3. 记录 tcpdump 的进程 ID：
```
echo $!
```

### CHECK

- tcpdump 是否开始运行了？
- 过滤器 `tcp port 8089` 的作用是什么？
