# TITLE: 反射型 XSS — 在 WebGoat 中练习
# STEP: 2
# MINUTES: 12

### WHY

反射型 XSS 最常出现在**搜索框**和**错误消息**中——应用直接把用户输入回显到页面上而不做转义。

攻击者需要诱导受害者点击一个特制的链接，链接中包含恶意脚本。

### DO

1. 启动实验：
```
cd ~/cyber-practice
./reset-lab.sh lab05
```

2. 访问 WebGoat：http://127.0.0.1:8080/WebGoat

3. 进入 (A7) Cross-Site Scripting (XSS) 课程

4. 完成反射型 XSS 练习：
   - 尝试在输入框中输入 `<script>alert('XSS')</script>`
   - 观察是否弹出对话框

5. 如果弹出了对话框，说明存在 XSS 漏洞

### CHECK

- [ ] 成功执行了反射型 XSS 吗？
- [ ] 截图保存证据
