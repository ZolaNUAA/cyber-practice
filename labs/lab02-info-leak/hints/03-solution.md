### 答案

泄露文件：
- db-backup.txt: 含数据库连接信息
- old-config.conf: 含 debug=true

修复：在 Nginx 配置中 deny /backup/ 路径并 return 404