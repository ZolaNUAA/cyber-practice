### 答案

扩展名绕过技巧：
- file.php.txt: 双扩展名
- file.PHP: 大小写
- file.php%00.jpg: 空字节(旧系统)

本实验的 upload-lab 使用 Python Flask，不解析 PHP，
所以即使上传成功也不会执行代码。但可以绕过内容检查。