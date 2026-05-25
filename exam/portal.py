#!/usr/bin/env python3
import html
import json
import os
import subprocess
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs

from audit import append_audit
from final_verify_runner import run_final_verify

ROOT = Path(__file__).resolve().parent
STATE_PATH = ROOT / "exam-state.json"
STUDENT_REPORT = ROOT / "latest-student-test.json"
FINAL_REPORT = ROOT / "latest-final-report.json"
BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8090")
HOST = os.environ.get("EXAM_PORTAL_HOST", "127.0.0.1")
PORT = int(os.environ.get("EXAM_PORTAL_PORT", "8091"))


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


def parse_iso(value: str):
    return datetime.fromisoformat(value) if value else None


def duration_text(state: dict) -> str:
    start = parse_iso(state.get("started_at"))
    if not start:
        return "未开始"
    if state.get("duration_seconds") is not None:
        seconds = int(state["duration_seconds"])
    else:
        seconds = int((datetime.now(timezone.utc) - start).total_seconds())
    minutes, sec = divmod(max(0, seconds), 60)
    return f"{minutes}分{sec}秒"


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


def render_findings(report: dict | None) -> str:
    if not report:
        return "<p class='muted'>暂无报告</p>"
    rows = []
    for item in report.get("findings", []):
        attack_ok = bool(item.get("attack_succeeded"))
        state = "VULNERABLE" if attack_ok else "FIXED"
        cls = "bad" if attack_ok else "good"
        rows.append(
            "<tr>"
            f"<td><span class='{cls}'>{state}</span></td>"
            f"<td>{html.escape(item.get('id', ''))}</td>"
            f"<td>{html.escape(item.get('title', ''))}</td>"
            f"<td>{item.get('points', '')}</td>"
            f"<td>{html.escape(item.get('evidence', ''))}</td>"
            "</tr>"
        )
    return """
    <table>
      <thead><tr><th>状态</th><th>编号</th><th>漏洞</th><th>分值</th><th>证据</th></tr></thead>
      <tbody>{}</tbody>
    </table>
    """.format("".join(rows))


def render_summary(report: dict | None) -> str:
    if not report:
        return "<p class='muted'>暂无检测结果</p>"
    findings = report.get("findings", [])
    total = len(findings)
    passed = sum(1 for item in findings if not item.get("attack_succeeded"))
    fixed_points = report.get("fixed_points", 0)
    total_points = report.get("total_points", 0)
    all_passed = bool(report.get("all_attacks_failed"))
    cls = "good" if all_passed else "bad"
    extra = "" if all_passed else "<p class='muted'>未全部通过，考试继续计时。可以继续修复后再次自测或提交验证。</p>"
    return f"""
    <p>
      <strong>通过题数：</strong>{passed}/{total}
      &nbsp; <strong>当前得分：</strong>{fixed_points}/{total_points}
      &nbsp; <strong>全部通过：</strong><span class="{cls}">{"是" if all_passed else "否"}</span>
    </p>
    {extra}
    """


def render_problem(started: bool) -> str:
    if not started:
        return "<p class='muted'>填写学号姓名后，点击“查看考题并开始计时”。计时从考题第一次显示时开始。</p>"
    return """
    <section class="panel">
      <h2>考试题目</h2>
      <p>目标：修补本地靶机，使公开自测脚本和教师最终验证脚本中的攻击都失败。</p>
      <p><strong>靶机地址：</strong>http://127.0.0.1:8090</p>
      <p><strong>主要修改位置：</strong>services/exam-gateway/default.conf</p>
      <p>本题围绕一个 Nginx 反向代理保护内部 Web 服务展开。内部服务存在 4 个可被脚本验证的风险入口，每项 25 分。具体拦截规则需要通过阅读网关配置、运行自测脚本、查看反馈和分析请求来判断。</p>
      <p class="muted">每次修改后，请重启网关服务：docker compose -f docker-compose.yml restart exam-gateway</p>
    </section>
    """


def page(message: str = "", final_error: str = "") -> bytes:
    state = load_state()
    started = bool(state.get("started_at"))
    finished = bool(state.get("finished_at"))
    student = state.get("last_student_test") or {}
    final = state.get("last_final_verify") or {}
    final_report = final.get("report") if isinstance(final, dict) else None
    student_report = student.get("report") if isinstance(student, dict) else None
    final_passed = bool(final_report and final_report.get("all_attacks_failed"))
    score = final_report.get("fixed_points") if final_report else "-"
    student_id = state.get("student_id") or ""
    student_name = state.get("student_name") or ""
    html_doc = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="10">
  <title>网络安全实践考试入口</title>
  <style>
    :root {{ color-scheme: light; --ink:#17202a; --muted:#64748b; --line:#d8dee9; --bg:#f7f8fb; --panel:#ffffff; --good:#127a3a; --bad:#b42318; --blue:#1d4ed8; }}
    * {{ box-sizing: border-box; }}
    body {{ margin:0; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color:var(--ink); background:var(--bg); }}
    header {{ background:#101827; color:white; padding:18px 24px; }}
    main {{ max-width:1120px; margin:0 auto; padding:24px; }}
    h1 {{ margin:0; font-size:22px; }}
    h2 {{ margin:0 0 12px; font-size:18px; }}
    .grid {{ display:grid; grid-template-columns: 1fr 1fr; gap:16px; }}
    .panel {{ background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:16px; margin-bottom:16px; }}
    .stats {{ display:grid; grid-template-columns: repeat(4, minmax(0,1fr)); gap:12px; }}
    .stat {{ border:1px solid var(--line); border-radius:8px; padding:12px; background:white; }}
    .label {{ color:var(--muted); font-size:13px; }}
    .value {{ font-size:24px; font-weight:700; margin-top:4px; }}
    button {{ border:0; border-radius:6px; padding:10px 14px; font-weight:700; cursor:pointer; background:var(--blue); color:white; }}
    button.secondary {{ background:#334155; }}
    button.danger {{ background:#b42318; }}
    input[type=password] {{ padding:10px; border:1px solid var(--line); border-radius:6px; min-width:240px; }}
    table {{ width:100%; border-collapse:collapse; font-size:14px; }}
    th, td {{ border-top:1px solid var(--line); padding:8px; vertical-align:top; text-align:left; }}
    th {{ color:var(--muted); font-weight:700; }}
    pre {{ white-space:pre-wrap; background:#0f172a; color:#e2e8f0; border-radius:8px; padding:12px; max-height:260px; overflow:auto; }}
    .good {{ color:var(--good); font-weight:800; }}
    .bad {{ color:var(--bad); font-weight:800; }}
    .muted {{ color:var(--muted); }}
    .msg {{ padding:10px 12px; border:1px solid #93c5fd; background:#eff6ff; border-radius:8px; margin-bottom:16px; }}
    .err {{ padding:10px 12px; border:1px solid #fecaca; background:#fef2f2; border-radius:8px; margin-bottom:16px; color:#991b1b; }}
    @media (max-width: 800px) {{ .grid, .stats {{ grid-template-columns:1fr; }} main {{ padding:14px; }} }}
  </style>
</head>
<body>
<header><h1>网络安全实践考试入口</h1></header>
<main>
  {f"<div class='msg'>{html.escape(message)}</div>" if message else ""}
  {f"<div class='err'>{html.escape(final_error)}</div>" if final_error else ""}

  <section class="stats">
    <div class="stat"><div class="label">考试状态</div><div class="value">{"已截止" if finished else ("进行中" if started else "未开始")}</div></div>
    <div class="stat"><div class="label">当前用时</div><div class="value">{duration_text(state)}</div></div>
    <div class="stat"><div class="label">最终得分</div><div class="value">{score}</div></div>
    <div class="stat"><div class="label">最终验证</div><div class="value">{"通过" if final_passed else "未通过"}</div></div>
  </section>

  <section class="panel">
    <h2>学生信息</h2>
    <p><strong>学号：</strong>{html.escape(student_id or '-')} &nbsp; <strong>姓名：</strong>{html.escape(student_name or '-')}</p>
    <p class="muted">操作审计日志：audit-log.jsonl</p>
  </section>

  <div class="grid">
    <section class="panel">
      <h2>学生操作</h2>
      <form method="post" action="/start" style="display:block;margin-bottom:10px">
        <input name="student_id" placeholder="学号" value="{html.escape(student_id)}" {"readonly" if started else ""}>
        <input name="student_name" placeholder="姓名" value="{html.escape(student_name)}" {"readonly" if started else ""}>
        <button {"disabled" if started else ""}>查看考题并开始计时</button>
      </form>
      <form method="post" action="/student-test" style="display:inline-block"><button class="secondary" {"disabled" if not started or finished else ""}>运行自测攻击脚本</button></form>
      <p class="muted">自测脚本可以反复运行；最终成绩只看教师验证。</p>
    </section>

    <section class="panel">
      <h2>教师最终验证</h2>
      <form method="post" action="/final-verify">
        <input type="password" name="password" placeholder="教师密码">
        <button class="danger" {"disabled" if not started or finished else ""}>最终成绩验证</button>
      </form>
      <p class="muted">教师密码用于临时解密最终验证脚本；全部通过后自动记录截止时间。</p>
    </section>
  </div>

  {render_problem(started)}

  <section class="panel">
    <h2>学生自测结果</h2>
    {render_summary(student_report)}
    {render_findings(student_report)}
    <pre>{html.escape((student or {}).get('output', ''))}</pre>
  </section>

  <section class="panel">
    <h2>教师最终结果</h2>
    <p>开始时间：{html.escape(state.get('started_at') or '-')}<br>截止时间：{html.escape(state.get('finished_at') or '-')}<br>最终用时：{duration_text(state)}</p>
    {render_summary(final_report)}
    {render_findings(final_report)}
    <pre>{html.escape((final or {}).get('output', ''))}</pre>
  </section>
</main>
</body>
</html>"""
    return html_doc.encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    def send_html(self, body: bytes) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.send_html(page())

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length).decode("utf-8", errors="replace")
        data = parse_qs(raw)
        state = load_state()

        if self.path == "/start":
            if not state.get("started_at"):
                student_id = (data.get("student_id") or [""])[0].strip()
                student_name = (data.get("student_name") or [""])[0].strip()
                if not student_id or not student_name:
                    self.send_html(page(final_error="请先填写学号和姓名。"))
                    return
                state["student_id"] = student_id
                state["student_name"] = student_name
                state["started_at"] = now_iso()
                save_state(state)
                append_audit(ROOT, state, "exam_started_by_viewing_problem", {"entry": "web"})
                self.send_html(page("考题已显示，计时已启动。"))
            else:
                self.send_html(page("考试已经开始。"))
            return

        if self.path == "/student-test":
            if not state.get("started_at"):
                self.send_html(page(final_error="请先点击“查看考题并开始计时”。"))
                return
            if state.get("finished_at"):
                self.send_html(page(final_error="考试已经截止，不能继续自测。"))
                return
            result = run_script("student_attack.py", STUDENT_REPORT)
            state["last_student_test"] = result
            save_state(state)
            report = result.get("report") or {}
            append_audit(
                ROOT,
                state,
                "student_test",
                {
                    "entry": "web",
                    "returncode": result.get("returncode"),
                    "fixed_points": report.get("fixed_points"),
                    "vulnerable_points": report.get("vulnerable_points"),
                    "all_attacks_failed": report.get("all_attacks_failed"),
                    "elapsed_ms": result.get("elapsed_ms"),
                },
            )
            self.send_html(page("学生自测已完成。"))
            return

        if self.path == "/final-verify":
            if not state.get("started_at"):
                self.send_html(page(final_error="请先点击“查看考题并开始计时”。"))
                return
            if state.get("finished_at"):
                self.send_html(page(final_error="考试已经截止。"))
                return
            password = (data.get("password") or [""])[0]
            result = run_final_verify(ROOT, BASE_URL, FINAL_REPORT, password)
            result["ran_at"] = now_iso()
            if result.get("report"):
                result["report"]["student_id"] = state.get("student_id")
                result["report"]["student_name"] = state.get("student_name")
            state["last_final_verify"] = result
            report = result.get("report") or {}
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
                        "entry": "web",
                        "returncode": result.get("returncode"),
                        "fixed_points": report.get("fixed_points"),
                        "vulnerable_points": report.get("vulnerable_points"),
                        "duration_seconds": state.get("duration_seconds"),
                        "elapsed_ms": result.get("elapsed_ms"),
                    },
                )
                self.send_html(page("最终验证全部通过，考试时间已截止。"))
            else:
                save_state(state)
                append_audit(
                    ROOT,
                    state,
                    "final_verify_failed",
                    {
                        "entry": "web",
                        "returncode": result.get("returncode"),
                        "fixed_points": report.get("fixed_points"),
                        "vulnerable_points": report.get("vulnerable_points"),
                        "elapsed_ms": result.get("elapsed_ms"),
                    },
                )
                self.send_html(page(final_error="最终验证未全部通过，考试继续计时。学生可以继续完善后再次提交验证。"))
            return

        self.send_html(page(final_error="未知操作。"))

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}")


def main() -> int:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Exam portal: http://{HOST}:{PORT}")
    print(f"Target base URL: {BASE_URL}")
    print("Teacher password is used to decrypt exam/final_verify.py.enc.")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
