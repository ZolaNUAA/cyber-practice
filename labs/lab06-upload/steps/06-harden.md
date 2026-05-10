# TITLE: 加固 — 文件上传安全方案
# STEP: 6
# MINUTES: 12

### WHY

文件上传安全的最佳实践：

**第一层 — 上传控制**：
- 白名单扩展名（只允许 `.jpg`, `.png`, `.pdf`）
- 验证 MIME 类型和文件魔术数字（magic bytes）
- 限制文件大小
- 病毒扫描

**第二层 — 存储控制**：
- 随机文件名（UUID），不暴露原始文件名
- 上传目录放在 Web 根目录之外
- 关闭上传目录的执行权限
- 不开启目录浏览

**第三层 — 执行控制**：
- 上传目录设置为只读
- 使用独立域名提供上传文件（如 `static.example.com`）
- Nginx：`location /uploads/ { add_header Content-Disposition attachment; }`

### DO

撰写实验报告，包含：
1. 上传证据和日志证据
2. 至少 3 条加固建议
3. 解释"上传"、"存储"、"执行"三层风险

### CHECK

报告完成了吗？
