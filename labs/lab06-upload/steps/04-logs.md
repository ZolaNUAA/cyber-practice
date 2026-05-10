# TITLE: 日志分析 — 查看 upload.log
# STEP: 4
# MINUTES: 8

### WHY

文件上传的每次操作都会被记录。日志分析能帮助你：
- 发现可疑的上传行为
- 追踪攻击者的活动
- 建立入侵检测规则

### DO

1. 查看上传日志：
```
tail -n 20 logs/upload/upload.log
```

2. 观察日志格式：
   - 时间戳
   - 来源 IP
   - 操作类型（upload_ok / upload_failed / download）
   - 文件名

3. 哪些文件名看起来可疑？

### CHECK

- 找到你的上传记录了吗？
- 如果同一 IP 短时间内上传了大量文件，你会在意哪些特征？
