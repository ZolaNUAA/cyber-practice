# 网络安全实践考试学生手册

## 1. 考试目标

你需要通过 Shell 命令和 Nginx 服务配置加固本地靶机网关，使公开自测脚本和教师最终验证脚本中的攻击都失败。

本考试考察的是 Linux 服务配置加固能力。请优先修改 Nginx 配置，不建议通过修改 Python 应用源码完成修复。

靶机地址：

```text
http://127.0.0.1:8090
```

主要修改文件：

```text
services/exam-gateway/default.conf
```

内部应用源码：

```text
services/exam-lab/app.py
```

内部应用源码可以阅读，用于理解后端行为；但本考试的推荐修复位置是 Nginx 网关配置。

## 2. 允许使用的材料

你可以使用：

- `./exam.sh` Shell 考试入口
- `STUDENT_BRIEF.md` 本手册
- `REPAIR_HINTS.md` 修复方向提示
- `student_attack.py` 公开自测脚本
- `services/exam-gateway/default.conf` Nginx 配置
- `services/exam-lab/app.py` 内部应用源码，仅用于理解
- 浏览器、curl、文本编辑器、Nginx 文档、搜索引擎和大模型

你不应该尝试修改、解密或替换教师最终验证相关文件。

## 3. 进入考试

在项目目录运行：

```bash
cd ~/cyber-practice
./exam.sh
```

首次进入时，系统会要求输入：

- 学号
- 姓名

请确认填写正确。考试状态、操作记录和最终报告都会记录这些信息。

## 4. 计时规则

计时从你第一次选择“查看考试题目 / 启动计时”开始。

进入菜单后，先选择：

```text
1. 查看考试题目 / 启动计时
```

从这一刻开始，系统会记录开始时间。

如果最终验证没有全部通过，考试不会截止，你可以继续修复、继续计时、再次提交教师验证。

只有教师最终验证全部通过时，系统才会记录截止时间。

## 5. 推荐操作流程

1. 运行 `./exam.sh`
2. 输入学号和姓名
3. 选择“查看考试题目 / 启动计时”
4. 阅读 `services/exam-gateway/default.conf`
5. 阅读并分析 `student_attack.py`
6. 根据自测反馈修改 Nginx 配置
7. 重启网关服务
8. 运行学生自测脚本
9. 重复修复，直到公开自测全部通过
10. 请老师输入密码运行最终验证

## 6. 重启网关服务

每次修改 Nginx 配置后，都需要重启网关服务：

```bash
docker compose -f docker-compose.yml restart exam-gateway
```

也可以在 `./exam.sh` 菜单中选择：

```text
7. 重启网关服务
```

如果配置写错，Nginx 容器可能无法正常工作。此时可以检查容器日志：

```bash
docker compose -f docker-compose.yml logs exam-gateway
```

## 7. 自测方式

在 `./exam.sh` 菜单中选择：

```text
5. 运行学生自测攻击脚本
```

也可以直接运行：

```bash
./setup-kali-exam.sh student-test
```

每次自测后，系统会显示：

- 通过题数
- 当前得分
- 是否全部通过
- 每个验证点的状态

状态含义：

- `VULNERABLE`：攻击仍然成功，需要继续修复
- `FIXED`：该项公开自测攻击失败

公开自测通过不代表最终一定通过。教师最终验证会使用不同的检测输入。

## 8. 评分规则

共有 4 个配置加固验证点，每项 25 分，总分 100 分。

最终成绩以教师最终验证为准。

公开自测脚本只用于帮助你判断修复方向。

如果教师最终验证未全部通过，考试继续计时，你可以继续完善配置后再次提交验证。

## 9. 操作记录

系统会记录考试过程中的关键操作，用于教师复核评分。

记录包括：

- 输入学号姓名
- 查看题目并开始计时
- 运行学生自测
- 重启网关服务
- 教师最终验证
- 最终截止时间

操作记录文件：

```text
audit-log.jsonl
```

状态和报告文件：

```text
exam-state.json
latest-student-test.json
latest-final-report.json
```

## 10. 注意事项

- 不要求唯一修复方式。
- 不建议修改 Python 应用源码。
- 不要修改公开自测脚本来伪造结果。
- 不要修改、替换或尝试解密教师最终验证脚本。
- 不要只针对公开脚本中的固定字符串做简单拦截。
- 修复后应保持 `http://127.0.0.1:8090/health` 正常可访问。
- 如果公开自测通过但教师验证失败，说明配置还不够通用，需要继续完善。

## 11. 常用命令

查看考试入口：

```bash
./exam.sh
```

运行公开自测：

```bash
./setup-kali-exam.sh student-test
```

重启网关：

```bash
docker compose -f docker-compose.yml restart exam-gateway
```

查看网关日志：

```bash
docker compose -f docker-compose.yml logs exam-gateway
```

查看容器状态：

```bash
docker compose -f docker-compose.yml ps
```

测试健康接口：

```bash
curl http://127.0.0.1:8090/health
```
