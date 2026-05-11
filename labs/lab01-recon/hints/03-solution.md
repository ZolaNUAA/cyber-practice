### 答案

```
nmap -sV -sC -p 3000,8080,8082,8086,8089,2222 127.0.0.1
```

预期发现：
- 2222: OpenSSH
- 8082: nginx
- 8086: HTTP (upload lab)
- 8089: HTTP (traffic lab)
- 3000: Node.js (Juice Shop)
- 8080: Java (WebGoat)
