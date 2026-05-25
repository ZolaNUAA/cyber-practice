# 网络安全实践考试方案

## 目标

学生在 Kali VM 中通过 Nginx 反向代理配置加固本地靶机。学生可以查看并运行公开的 `student_attack.py` 自测；教师最终使用加密的 `final_verify.py.enc` 验收。最终成绩以教师脚本为准，再结合完成时间排序或加分。

这版考试降为 4 个核心验证点，修补方式以 Shell/Nginx 配置为主，更适合做 Linux 服务加固考试。允许使用大模型和联网资料时，高水平学生约 30 分钟完成，基础较弱学生约 60-90 分钟完成。

## 漏洞与难度

| 编号 | 漏洞 | 分值 | 难度 | 预期修补点 |
|---|---|---:|---|---|
| BACKUP_EXPOSURE | 备份文件可直接访问 | 25 | 易 | 禁止 Web 访问备份目录 |
| DIRECTORY_LISTING | 目录索引暴露内部文件名 | 25 | 易 | 关闭目录索引或禁止访问敏感目录 |
| ADMIN_PATH_EXPOSURE | 管理路径未限制访问 | 25 | 易-中 | 禁止公开访问管理路径 |
| ACTIVE_UPLOAD_CONTENT | 上传目录主动内容可直接访问 | 25 | 中 | 禁止访问上传目录中的主动内容文件 |

满分基础分 100。`grade.py` 默认时间加分为：30 分钟内 +10，60 分钟内 +6，90 分钟内 +3，总分封顶 100。也可以不使用时间加分，只把完成时间作为同分排序依据。

## 双脚本设计

- `student_attack.py`：发给学生，允许阅读、运行、分析 payload。它帮助学生理解攻击为什么成功，以及修补后是否大概率有效。
- `final_verify.py.enc`：教师最终验收脚本密文。老师输入密码后临时解密运行，运行后删除临时文件。同类漏洞、不同 payload、随机 nonce，防止学生只针对公开脚本里的固定字符串做拦截。

这个设计的目的不是保密漏洞类别，而是让学生有足够抓手完成修复，同时保证最终验证还有独立性。

## 教师部署

```bash
cd /path/to/exam
./setup-kali-exam.sh reset
./setup-kali-exam.sh portal
```

靶机地址：`http://127.0.0.1:8090`

考试入口：`http://127.0.0.1:8091`

Shell 入口：

```bash
./exam.sh
# 或
./setup-kali-exam.sh shell
```

另开一个终端可以检查脚本哈希：

```bash
./setup-kali-exam.sh checksum
```

## 学生任务说明

建议发给学生这些文件：

- `services/exam-lab/app.py`
- `services/exam-gateway/default.conf`
- `student_attack.py`
- `STUDENT_BRIEF.md`
- `REPAIR_HINTS.md`
- `docker-compose.yml`

学生可以打开入口页面：

```text
http://127.0.0.1:8091
```

也可以直接进入 Shell 菜单：

```bash
./exam.sh
```

点击或选择“查看考题”后计时开始；“运行自测攻击脚本”可以反复确认修复情况。也可以在终端运行：

```bash
./setup-kali-exam.sh student-test
```

修改 `services/exam-gateway/default.conf` 后重启网关服务：

```bash
docker compose -f docker-compose.yml restart exam-gateway
```

## 教师验收

推荐使用入口页面验收：老师输入教师密码并点击“最终成绩验证”。如果 4 项全部通过，页面会自动记录截止时间，显示最终完成用时，并保存 `latest-final-report.json`。

也可以使用终端验收：

```bash
./setup-kali-exam.sh final-verify
./grade.py latest-final-report.json --minutes 54
```

`VULNERABLE` 表示攻击仍成功，`FIXED` 表示该攻击失败。

当前示例包的最终验证密文使用 `TeacherPass2026!` 加密。正式考试前建议教师用自己的强密码重新生成 `final_verify.py.enc`，并删除任何明文验证脚本。

## 操作历史

系统会把关键操作写入：

```text
audit-log.jsonl
```

每一行是一个 JSON 事件，包含时间、学号、姓名、动作和结果摘要。记录的动作包括：

- `student_identity_set`
- `exam_started_by_viewing_problem`
- `student_test`
- `target_restarted`
- `final_verify_failed`
- `final_verify_passed_exam_finished`

查看方式：

```bash
cat audit-log.jsonl
jq . audit-log.jsonl
```

建议评分归档时保存：

- `exam-state.json`
- `audit-log.jsonl`
- `latest-student-test.json`
- `latest-final-report.json`
- 学生修改后的 `services/exam-gateway/default.conf`

## 防作弊设计

1. 学生可以看 `student_attack.py`，但最终成绩不使用学生本地报告。
2. 教师保留最终验证密码。学生可以看到 `final_verify.py.enc`，但看不到明文脚本。
3. 教师验收前运行 `setup-kali-exam.sh checksum`，确认最终验证脚本未被替换。
4. 最终验证脚本使用随机 nonce 和不同 payload，避免只拦截固定攻击字符串。
5. 学生只提交修补后的代码、镜像或 VM 快照；报告由教师生成并归档。
6. 若只能在学生机运行最终脚本，应现场从教师可信来源复制脚本，执行后立即保存 JSON 报告。

## 可操作流程

1. 考前：教师运行 `reset`，确认 `student-test` 和 `final-verify` 初始都能打出 4 项 `VULNERABLE`。
2. 启动入口：教师运行 `setup-kali-exam.sh portal`。
3. Shell 入口可选：学生运行 `./exam.sh`，可以查看题目、提示、自测、计时和重启网关服务。
4. 开考：学生在 Web 入口或 Shell 入口点击/选择“查看考题”，计时开始。
5. 过程中：学生可查资料、问大模型、修改 Nginx 配置、重启网关服务，并反复运行“学生自测攻击脚本”。
6. 提交：老师在 Web 入口或 Shell 入口输入密码并运行“最终成绩验证”。
7. 截止：如果最终验证全通过，系统自动记录截止时间和完成用时；未全通过则继续计时。
8. 复核：以最终验证 evidence、`latest-final-report.json`、`audit-log.jsonl` 和 `exam-data/logs/exam.log` 为准。

## 初始验证

```bash
./setup-kali-exam.sh reset
./setup-kali-exam.sh student-test
./setup-kali-exam.sh final-verify
./setup-kali-exam.sh portal
./exam.sh
```

初始靶机应显示 4 项 `VULNERABLE`。修补完成后，教师最终验证应显示 4 项 `FIXED`。
