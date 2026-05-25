#!/usr/bin/env python3
import getpass
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from audit import append_audit
from final_verify_runner import run_final_verify

ROOT = Path(__file__).resolve().parent
STATE_PATH = ROOT / "exam-state.json"
STUDENT_REPORT = ROOT / "latest-student-test.json"
FINAL_REPORT = ROOT / "latest-final-report.json"
BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8090")

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
MAGENTA = "\033[35m"
CYAN = "\033[36m"


def c(text: str, color: str) -> str:
    if os.environ.get("NO_COLOR"):
        return text
    return f"{color}{text}{RESET}"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_state() -> dict:
    if STATE_PATH.exists():
        try:
            return json.loads(STATE_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            pass
    return {
        "student_id": None,
        "student_name": None,
        "started_at": None,
        "finished_at": None,
        "duration_seconds": None,
        "last_student_test": None,
        "last_final_verify": None,
    }


def save_state(state: dict) -> None:
    STATE_PATH.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def parse_iso(value: str | None):
    return datetime.fromisoformat(value) if value else None


def duration_seconds(state: dict) -> int | None:
    started = parse_iso(state.get("started_at"))
    if not started:
        return None
    if state.get("duration_seconds") is not None:
        return int(state["duration_seconds"])
    return int((datetime.now(timezone.utc) - started).total_seconds())


def duration_text(state: dict) -> str:
    seconds = duration_seconds(state)
    if seconds is None:
        return "未开始"
    minutes, sec = divmod(max(0, seconds), 60)
    return f"{minutes}分{sec}秒"


def pause() -> None:
    input("\n按 Enter 返回菜单...")


def clear() -> None:
    os.system("clear")


def run_script(script: str, report: Path) -> dict:
    cmd = ["python3", str(ROOT / script), "--base-url", BASE_URL, "--json", str(report)]
    started = time.monotonic()
    proc = subprocess.run(cmd, cwd=str(ROOT), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    elapsed_ms = int((time.monotonic() - started) * 1000)
    parsed = None
    if report.exists():
        try:
            parsed = json.loads(report.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            parsed = None
    return {
        "cmd": " ".join(cmd),
        "returncode": proc.returncode,
        "elapsed_ms": elapsed_ms,
        "output": proc.stdout[-6000:],
        "report": parsed,
        "ran_at": now_iso(),
    }


def print_status() -> None:
    state = load_state()
    status = "未开始"
    status_color = YELLOW
    if state.get("finished_at"):
        status = "已截止"
        status_color = GREEN
    elif state.get("started_at"):
        status = "进行中"
        status_color = CYAN
    print(f"{c('状态', BOLD)}：{c(status, status_color)}")
    print(f"{c('学生', BOLD)}：{state.get('student_id') or '-'} {state.get('student_name') or ''}".rstrip())
    print(f"{c('靶机', BOLD)}：{c(BASE_URL, BLUE)}")
    print(f"{c('用时', BOLD)}：{c(duration_text(state), MAGENTA)}")
    print(f"{c('开始时间', BOLD)}：{state.get('started_at') or '-'}")
    print(f"{c('截止时间', BOLD)}：{state.get('finished_at') or '-'}")
    final = state.get("last_final_verify") or {}
    report = final.get("report") if isinstance(final, dict) else None
    if report:
        print(f"最终得分：{report.get('fixed_points', '-')}/{report.get('total_points', '-')}")
        verify = "通过" if report.get("all_attacks_failed") else "未通过"
        print(f"最终验证：{c(verify, GREEN if report.get('all_attacks_failed') else RED)}")


def show_file(title: str, path: Path) -> None:
    clear()
    print(f"===== {title} =====\n")
    print(path.read_text(encoding="utf-8"))
    pause()


def show_problem() -> None:
    state = ensure_student_identity()
    if not state.get("started_at"):
        state["started_at"] = now_iso()
        save_state(state)
        append_audit(ROOT, state, "exam_started_by_viewing_problem", {"entry": "shell"})
    clear()
    print(c("===== 考试题目 =====\n", BOLD + CYAN))
    print("目标：修补本地靶机，使公开自测脚本和教师最终验证脚本中的攻击都失败。")
    print(f"靶机地址：{c(BASE_URL, BLUE)}")
    print(f"主要修改位置：{c('services/exam-gateway/default.conf', YELLOW)}\n")
    print("范围：")
    print("- 本题围绕一个 Nginx 反向代理保护内部 Web 服务展开。")
    print("- 内部服务存在 4 个可被脚本验证的风险入口，每项 25 分。")
    print("- 具体拦截规则需要你通过阅读 Nginx 配置、运行自测脚本、查看反馈和分析请求来判断。\n")
    print("规则：")
    print("- 可以查看 exam/student_attack.py，允许联网和使用大模型。")
    print("- 不要求唯一修复方式，只要求网关配置后攻击验证失败。")
    print("- 不建议修改 Python 应用；主要通过 Shell/Nginx 配置完成加固。")
    print("- 每次修改后需要重启网关服务，让配置变更生效。")
    print("- 教师最终验证脚本与学生自测脚本不同，最终成绩以教师验证为准。")
    pause()


def ensure_student_identity() -> dict:
    state = load_state()
    if state.get("student_id") and state.get("student_name"):
        return state
    clear()
    print(c("===== 学生信息 =====\n", BOLD + CYAN))
    while True:
        student_id = input("请输入学号：").strip()
        if student_id:
            break
        print("学号不能为空。")
    while True:
        student_name = input("请输入姓名：").strip()
        if student_name:
            break
        print("姓名不能为空。")
    state["student_id"] = student_id
    state["student_name"] = student_name
    save_state(state)
    append_audit(ROOT, state, "student_identity_set", {"entry": "shell"})
    print("\n学生信息已记录。")
    time.sleep(0.6)
    return state


def start_exam() -> None:
    show_problem()


def show_status_screen() -> None:
    clear()
    print(c("===== 当前状态 =====\n", BOLD + CYAN))
    print_status()
    pause()


def student_test() -> None:
    state = load_state()
    if not state.get("started_at"):
        print("请先查看考试题目，计时会从查看题目开始。")
        pause()
        return
    if state.get("finished_at"):
        print("考试已经截止，不能继续自测。")
        pause()
        return
    if not state.get("student_id") or not state.get("student_name"):
        state = ensure_student_identity()
    print("正在运行学生自测攻击脚本...\n")
    result = run_script("student_attack.py", STUDENT_REPORT)
    state["last_student_test"] = result
    save_state(state)
    report = result.get("report") or {}
    append_audit(
        ROOT,
        state,
        "student_test",
        {
            "entry": "shell",
            "returncode": result.get("returncode"),
            "fixed_points": report.get("fixed_points"),
            "vulnerable_points": report.get("vulnerable_points"),
            "all_attacks_failed": report.get("all_attacks_failed"),
            "elapsed_ms": result.get("elapsed_ms"),
        },
    )
    print(colorize_output(result["output"]))
    print()
    print(report_summary(report))
    pause()


def teacher_verify() -> None:
    state = load_state()
    if not state.get("started_at"):
        print("请先查看考试题目，计时会从查看题目开始。")
        pause()
        return
    if state.get("finished_at"):
        print("考试已经截止。")
        pause()
        return
    if not state.get("student_id") or not state.get("student_name"):
        state = ensure_student_identity()
    password = getpass.getpass("教师密码：")
    print("正在运行教师最终验证脚本...\n")
    result = run_final_verify(ROOT, BASE_URL, FINAL_REPORT, password)
    result["ran_at"] = now_iso()
    if result.get("report"):
        result["report"]["student_id"] = state.get("student_id")
        result["report"]["student_name"] = state.get("student_name")
    state["last_final_verify"] = result
    report = result.get("report") or {}
    print(colorize_output(result["output"]))
    print()
    print(report_summary(report))
    if report.get("all_attacks_failed"):
        finished = datetime.now(timezone.utc)
        started = parse_iso(state.get("started_at"))
        state["finished_at"] = finished.isoformat()
        state["duration_seconds"] = int((finished - started).total_seconds()) if started else None
        if result.get("report"):
            result["report"]["finished_at"] = state["finished_at"]
            result["report"]["duration_seconds"] = state["duration_seconds"]
            FINAL_REPORT.write_text(json.dumps(result["report"], ensure_ascii=False, indent=2), encoding="utf-8")
        save_state(state)
        append_audit(
            ROOT,
            state,
            "final_verify_passed_exam_finished",
            {
                "entry": "shell",
                "returncode": result.get("returncode"),
                "fixed_points": report.get("fixed_points"),
                "vulnerable_points": report.get("vulnerable_points"),
                "duration_seconds": state.get("duration_seconds"),
                "elapsed_ms": result.get("elapsed_ms"),
            },
        )
        print(f"\n最终验证全部通过，考试截止。最终用时：{duration_text(state)}")
    else:
        save_state(state)
        append_audit(
            ROOT,
            state,
            "final_verify_failed",
            {
                "entry": "shell",
                "returncode": result.get("returncode"),
                "fixed_points": report.get("fixed_points"),
                "vulnerable_points": report.get("vulnerable_points"),
                "elapsed_ms": result.get("elapsed_ms"),
            },
        )
        print("\n最终验证未全部通过，考试继续计时。学生可以继续完善后再次提交验证。")
    pause()


def rebuild_target() -> None:
    print("正在重启网关服务...\n")
    cmd = ["docker", "compose", "-f", "docker-compose.yml", "restart", "exam-gateway"]
    proc = subprocess.run(cmd, cwd=str(ROOT), text=True)
    append_audit(ROOT, load_state(), "target_restarted", {"entry": "shell", "returncode": proc.returncode})
    print(f"\n命令退出码：{proc.returncode}")
    pause()


def show_latest_report(kind: str) -> None:
    clear()
    state = load_state()
    key = "last_student_test" if kind == "student" else "last_final_verify"
    latest = state.get(key) or {}
    report = latest.get("report") if isinstance(latest, dict) else None
    print("===== 最近报告 =====\n")
    if not report:
        print("暂无报告。")
        pause()
        return
    for item in report.get("findings", []):
        status = "VULNERABLE" if item.get("attack_succeeded") else "FIXED"
        status_text = c(f"[{status}]", RED if item.get("attack_succeeded") else GREEN)
        print(f"{status_text} {item.get('id')} ({item.get('points')}分) {item.get('title')}")
        evidence = item.get("evidence")
        if evidence:
            print(f"  evidence: {evidence}")
    print(f"\n已修复分：{report.get('fixed_points')}/{report.get('total_points')}")
    print(f"全部攻击失败：{report.get('all_attacks_failed')}")
    pause()


def colorize_output(output: str) -> str:
    lines = []
    for line in output.splitlines():
        if line.startswith("[VULNERABLE]"):
            lines.append(c(line, RED))
        elif line.startswith("[FIXED]"):
            lines.append(c(line, GREEN))
        elif "all_attacks_failed=True" in line:
            lines.append(c(line, GREEN + BOLD))
        elif "all_attacks_failed=False" in line:
            lines.append(c(line, RED + BOLD))
        else:
            lines.append(line)
    return "\n".join(lines)


def report_summary(report: dict | None) -> str:
    if not report:
        return c("未生成有效检测报告。", RED)
    findings = report.get("findings", [])
    total = len(findings)
    passed = sum(1 for item in findings if not item.get("attack_succeeded"))
    fixed_points = report.get("fixed_points", 0)
    total_points = report.get("total_points", 0)
    all_passed = bool(report.get("all_attacks_failed"))
    color = GREEN if all_passed else YELLOW
    lines = [
        c("===== 检测结果汇总 =====", BOLD + color),
        f"通过题数：{passed}/{total}",
        f"当前得分：{fixed_points}/{total_points}",
        f"全部通过：{'是' if all_passed else '否'}",
    ]
    if not all_passed:
        lines.append(c("未全部通过，考试继续计时。请继续修复后再次自测。", YELLOW))
    return "\n".join(lines)


def menu() -> None:
    ensure_student_identity()
    while True:
        clear()
        print(c("========================================", CYAN))
        print(c("        网络安全实践考试 Shell 入口", BOLD + CYAN))
        print(c("========================================", CYAN))
        print_status()
        print(c("\n菜单：", BOLD))
        print(f"{c('1.', YELLOW)} 查看考试题目 / 启动计时")
        print(f"{c('2.', YELLOW)} 查看当前状态 / 用时")
        print(f"{c('3.', YELLOW)} 查看修复提示")
        print(f"{c('4.', YELLOW)} 查看学生说明")
        print(f"{c('5.', YELLOW)} 运行学生自测攻击脚本")
        print(f"{c('6.', YELLOW)} 查看最近学生自测报告")
        print(f"{c('7.', YELLOW)} 重启网关服务")
        print(f"{c('8.', YELLOW)} 显示需要修改的文件路径")
        print(f"{c('9.', RED)} 教师最终验证并截止计时")
        print(f"{c('10.', YELLOW)} 查看最近教师最终报告")
        print(f"{c('0.', DIM)} 退出")
        try:
            choice = input("\n请选择：").strip()
        except EOFError:
            return
        if choice == "1":
            start_exam()
        elif choice == "2":
            show_status_screen()
        elif choice == "3":
            show_file("修复提示", ROOT / "REPAIR_HINTS.md")
        elif choice == "4":
            show_file("学生说明", ROOT / "STUDENT_BRIEF.md")
        elif choice == "5":
            student_test()
        elif choice == "6":
            show_latest_report("student")
        elif choice == "7":
            rebuild_target()
        elif choice == "8":
            clear()
            print("主要修改文件：")
            print(str(ROOT / "services" / "exam-gateway" / "default.conf"))
            print("\n内部脆弱应用源码仅供理解，不建议修改：")
            print(str(ROOT / "services" / "exam-lab" / "app.py"))
            print("\n自测脚本：")
            print(str(ROOT / "student_attack.py"))
            print("\n重启命令：")
            print("docker compose -f docker-compose.yml restart exam-gateway")
            pause()
        elif choice == "9":
            teacher_verify()
        elif choice == "10":
            show_latest_report("final")
        elif choice == "0":
            return
        else:
            print("无效选择。")
            pause()


if __name__ == "__main__":
    try:
        menu()
    except KeyboardInterrupt:
        print("\n已退出。")
        sys.exit(0)
