# Lab02：Web 信息泄露

## 学习目标

1. 发现 Web 服务器的配置错误（备份目录暴露）
2. 分析信息泄露对整体安全的影响
3. 理解 Nginx 配置中的安全风险点
4. 掌握日志分析方法

## 预备知识

### 什么是信息泄露？

信息泄露（Information Disclosure）属于 **OWASP Top 10 2021 第七位**，指 Web 应用在错误信息、备份文件、配置文件、调试接口等处暴露了本不该公开的信息。

**真实案例**：
- 2019 年美军超过 22TB 伊朗火箭数据泄露——起因是一台 ElasticSearch 服务器没有密码保护，可直接访问索引内容
- 大量 `.git` 目录通过 GitHub Pages 直接访问，导致源码泄露
- 本地 `docker-compose.yml` 中泄露数据库密码

### 信息泄露为什么危险？

```
攻击者的利用路径：

1. 发现备份目录 /backup/
   ↓
2. 下载 db-backup.txt
   ↓
3. 发现数据库连接字符串：root:password@mysql-host
   ↓
4. 用这个密码连接 MySQL 或 SSH
   ↓
5. 横向移动，获得更高权限
```

**核心问题**：信息泄露通常不是"直接漏洞"，但它是攻击链中的关键跳板。

### 本实验的漏洞原理

```nginx
# labs/nginx-lab/default.conf 中的危险配置
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # 危险！开启目录列表
    location /backup/ {
        autoindex on;   # 任何人都能列出目录内容
    }
}
```

`autoindex on` 使得 `/backup/` 目录可以被任何人浏览，目录中的所有文件（db-backup.txt、old-config.conf）均可直接下载。

## 实验环境

```bash
./student.sh  # 选择对应的实验开始
```

**目标服务**：http://127.0.0.1:8082
**漏洞路径**：/backup/ （故意暴露的备份目录）

## 操作步骤

### 步骤 1：确认服务可用

```bash
curl -I http://127.0.0.1:8082/
```

**观察要点**：
- HTTP 状态码（应为 200）
- Server Header（nginx 版本号）
- 是否有任何安全相关的 Header（如 `X-Frame-Options`、`X-Content-Type-Options`）

**记录**：
```
HTTP/1.1 200 OK
Server: nginx/1.25-alpine
X-Frame-Options: ??? (缺失 = 不安全)
```

### 步骤 2：探测备份目录

```bash
# 访问备份目录（触发目录列表）
curl -I http://127.0.0.1:8082/backup/
```

**你应该观察**：
- HTTP 状态码（如果返回 200 或 403，说明目录存在）
- 如果返回 403 或 404，说明 `autoindex` 可能没有开启或路径不对

```bash
# 获取目录列表的 HTML 内容
curl http://127.0.0.1:8082/backup/
```

**预期输出示例**：
```html
<!DOCTYPE html>
<html>
<head><title>Index of /backup/</title></head>
<body>
<h1>Index of /backup/</h1>
<ul>
<li><a href="db-backup.txt">db-backup.txt</a></li>
<li><a href="old-config.conf">old-config.conf</a></li>
</ul>
</body>
</html>
```

**你应该记录**：
- 目录列表中出现了哪些文件
- 文件名是否暗示内容（如 `db-backup.txt` → 数据库备份）

### 步骤 3：下载并分析备份文件

```bash
# 下载数据库备份
curl http://127.0.0.1:8082/backup/db-backup.txt

# 观察：文件内容是否包含敏感信息？
# 可能的内容：
# - 数据库连接字符串
# - 用户名/密码
# - API 密钥
# - 程序源码或配置
```

```bash
# 下载配置文件
curl http://127.0.0.1:8082/backup/old-config.conf

# 观察：
# - 是否有硬编码的密码或密钥？
# - 是否暴露了内部网络结构？
# - 配置文件版本是否对应已知漏洞的版本？
```

**你应该记录**：
```
文件：db-backup.txt
内容摘要：[粘贴关键内容]
敏感信息发现：
  - 数据库用户名/密码
  - API 密钥
  - 其他

文件：old-config.conf
内容摘要：[粘贴关键内容]
配置问题：
  - 暴露的内部路径
  - 旧版本组件（可能对应 CVE）
```

### 步骤 4：分析 Nginx 日志

```bash
# 查看最近的访问日志
tail -n 50 logs/nginx/access.log
```

**观察要点**：
```
127.0.0.1 - - [10/May/2026:09:00:00 +0000] "GET /backup/ HTTP/1.1" 200 232 "-" "curl/8.0"
127.0.0.1 - - [10/May/2026:09:00:05 +0000] "GET /backup/db-backup.txt HTTP/1.1" 200 1543 "-" "curl/8.0"
```

**你应该关注**：
1. 谁在什么时间访问了 `/backup/` 路径？（源 IP）
2. 是否有人用脚本批量扫描（大量 404 请求不同的路径）？
3. 404 的路径是否暗示攻击者已经在尝试常见备份文件名？

```bash
# 统计访问量最多的路径（找扫描行为）
awk '{print $7}' logs/nginx/access.log | sort | uniq -c | sort -rn | head -20
```

### 步骤 5：提出防御方案

基于你的发现，回答以下问题：

**问题 1**：当前的 Nginx 配置中，哪个指令导致了信息泄露？
**问题 2**：如果你是系统管理员，你如何修改配置来修复这个问题？

**防御方案参考**：

```nginx
# 方案 1：完全禁止访问备份目录
location /backup/ {
    deny all;
}

# 方案 2：返回 404（迷惑攻击者，不知道目录存在）
location /backup/ {
    return 404;
}

# 方案 3：添加认证（适用于需要临时共享文件的场景）
location /backup/ {
    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

**你还应该考虑**的安全配置：
```nginx
# 隐藏 nginx 版本号
server_tokens off;

# 禁止访问隐藏文件
location ~ /\. {
    deny all;
}

# 禁止访问 .git 目录
location ~ /\.git {
    deny all;
}
```

## 技术原理

### Nginx autoindex 模块

`autoindex` 是 nginx 的一个内置模块，当开启后：
1. 客户端请求一个目录路径（如 `/backup/`）
2. nginx 检查该目录存在，但目录下没有 `index.html`
3. nginx 生成目录列表 HTML（类似 FTP 索引）
4. 返回给客户端

**危害评估**：
- 低风险：攻击者只知道有文件，但不知道文件名
- **高风险（autoindex on）**：攻击者可以看到完整文件列表，逐个下载

### 信息泄露的分类

| 类型 | 示例 | 危害程度 |
|------|------|---------|
| 目录遍历 | `/../../etc/passwd` | 高（直接读取系统文件）|
| 备份文件暴露 | `/backup/db.sql` | **极高**（完整数据库）|
| 版本信息泄露 | `Server: nginx/1.25` | 中（缩小漏洞搜索范围）|
| 错误信息泄露 | Stack Trace 输出 | 中高（泄露代码路径）|
| Git 目录 | `/.git/config` | **极高**（完整源码）|
| 配置文件 | `/.env` | **极高**（凭据泄露）|

## 思考题

### 思考题 1：为什么信息泄露即使"没有直接漏洞"也是高危的？

分析攻击者拿到一份数据库备份文件（`db-backup.txt`）后，可能的后续动作。考虑：
- 文件中可能包含哪些类型的敏感信息？
- 攻击者会如何使用这些信息？
- 这和信息收集阶段有什么关系？

### 思考题 2：即使关闭 `autoindex`，攻击者还能获取备份文件吗？

假设：
- `autoindex` 已经关闭（返回 403）
- 攻击者不知道备份目录的具体文件名

请列举攻击者仍可能获取备份文件的方法（至少 3 种）。

### 思考题 3：日志分析 — 识别扫描行为

查看你的 access.log，回答：
- 是否有人在短时间内请求了大量不同的路径？
- 如何区分"用户正常浏览"和"攻击者扫描"？
- 如果你发现大量 `404` 请求 `/backup/.env`、`/backup/config.php` 等，这说明什么？

### 思考题 4：防御的优先级

作为安全工程师，你发现服务器上同时存在以下问题：
1. `/backup/` 目录暴露且 autoindex 开启
2. nginx 版本号暴露（Server Header 显示 1.25-alpine）
3. 没有配置 `X-Frame-Options` Header

如果只能修复一个，你会优先修哪个？为什么？从攻击者的视角思考这个问题。

## 交付物

1. **备份目录内容列表**（截图或 curl 输出）
2. **备份文件内容摘要**（分析发现哪些敏感信息）
3. **Nginx 日志分析报告**（正常访问 + 可疑行为）
4. **防御方案配置**（修复 `autoindex on` 的具体配置）
5. **思考题答案**（不少于 3 题）

## 工具速查

```bash
# 目录探测
curl -I http://127.0.0.1:8082/backup/
curl http://127.0.0.1:8082/backup/

# 批量文件检查（常见备份文件名）
for f in db-backup.txt config.bak .env.backup old-config.conf; do
    curl -s -o /dev/null -w "%{http_code} %{url_effective}\n" http://127.0.0.1:8082/backup/$f
done

# 日志分析
tail -f logs/nginx/access.log                  # 实时监控
awk '{print $7}' logs/nginx/access.log | sort | uniq -c | sort -rn | head -10  # 热门路径
grep -E "404|403" logs/nginx/access.log | head -20  # 异常请求
```