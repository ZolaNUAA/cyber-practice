### 提示

尝试双扩展名绕过：
```
curl -F "file=@test.php.txt" http://127.0.0.1:8086/upload
```

secure_filename 会保留这个文件名。