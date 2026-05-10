# TITLE: 加固 — 密码策略与防御方案
# STEP: 5
# MINUTES: 12

### WHY

SSH 加固应该遵循**纵深防御**原则：

1. **强密码策略**：最小长度、复杂度要求、定期更换
2. **禁用 root 登录**：`PermitRootLogin no`
3. **密钥认证**：禁用密码登录，只用 SSH Key
4. **速率限制**：使用 fail2ban 自动封禁暴力破解 IP
5. **更改默认端口**：减少自动化扫描的噪音（安全通过隐蔽性，辅助措施）
6. **双因素认证**：SSH + Google Authenticator

### DO

撰写一份 SSH 加固建议清单：

1. 在 `/etc/ssh/sshd_config` 中推荐修改：
   - `PermitRootLogin no`
   - `PasswordAuthentication no`（启用密钥后）
   - `MaxAuthTries 3`

2. 推荐安装 fail2ban：
   ```
   apt install fail2ban
   ```
   配置 SSH jail 在 3 次失败后封禁 10 分钟

3. 建议密码策略：
   - 最少 12 字符
   - 包含大小写字母+数字+符号
   - 不在常见密码字典中

### CHECK

报告中是否包含：
- [ ] 至少 3 条 SSH 配置加固建议
- [ ] fail2ban 部署说明
- [ ] 弱密码风险分析
