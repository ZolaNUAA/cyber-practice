# TITLE: 绕过 — 扩展名绕过尝试
# STEP: 3
# MINUTES: 10

### WHY

攻击者的目标是上传一个**可执行**的文件（如 PHP、JSP、ASP），然后通过 URL 访问它来执行任意代码。

常见的绕过技巧：
- **双扩展名**：`shell.php.txt` → 某些配置下当 PHP 解析
- **大小写**：`shell.PHP`
- **空字节**：`shell.php%00.jpg`（已被现代系统修复）
- **MIME 类型伪造**：修改 Content-Type 头

本实验的 `secure_filename` 函数会过滤文件名，但不会阻止你上传任意内容。

### DO

1. 上传带有 `.php.txt` 扩展名的文件：
```
echo '<?php echo "test"; ?>' > /tmp/test.php.txt
curl -F "file=@/tmp/test.php.txt" http://127.0.0.1:8086/upload
```

2. 查看上传列表：
```
curl http://127.0.0.1:8086/uploads
```

3. 尝试访问上传的文件：
```
curl http://127.0.0.1:8086/uploads/test.php.txt
```

### CHECK

- 文件上传成功了吗？
- 访问文件时是显示内容还是执行了代码？为什么？
