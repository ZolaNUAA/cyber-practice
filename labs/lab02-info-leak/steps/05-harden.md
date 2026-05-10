# TITLE: 防御 — Nginx 加固方案
# STEP: 5
# MINUTES: 12

### WHY

修复信息泄露的核心措施：
1. 关闭目录浏览：autoindex off
2. 禁止访问敏感目录：deny all; return 404
3. 移除备份文件
4. 返回 404 而非 403（不暴露目录存在）

### DO

提出 Nginx 加固方案：
```
location /backup/ {
    deny all;
    return 404;
}
```

### CHECK

报告中是否包含加固方案和至少 2 条安全建议？
