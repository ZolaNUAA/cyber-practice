#!/usr/bin/env python3
import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Dict, List, Tuple


@dataclass
class Finding:
    id: str
    title: str
    points: int
    attack_succeeded: bool
    evidence: str
    elapsed_ms: int


def request(base: str, path: str) -> Tuple[int, str, Dict[str, str]]:
    req = urllib.request.Request(base.rstrip("/") + path, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return resp.status, resp.read().decode("utf-8", errors="replace"), dict(resp.headers)
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace"), dict(exc.headers)


def run_check(check_id: str, title: str, points: int, fn) -> Finding:
    started = time.monotonic()
    try:
        ok, evidence = fn()
    except Exception as exc:
        ok, evidence = False, f"check_error={type(exc).__name__}: {exc}"
    return Finding(check_id, title, points, ok, evidence[:500], int((time.monotonic() - started) * 1000))


def checks(base: str) -> List[Finding]:
    return [
        run_check(
            "BACKUP_EXPOSURE",
            "备份文件可直接访问",
            25,
            lambda: (
                (lambda status, body, headers: (
                    status == 200 and "ExamBackupRootCause2026" in body,
                    f"GET /backup/db-backup.txt status={status}",
                ))(*request(base, "/backup/db-backup.txt"))
            ),
        ),
        run_check(
            "DIRECTORY_LISTING",
            "目录索引暴露内部文件名",
            25,
            lambda: (
                (lambda status, body, headers: (
                    status == 200 and "Index of /public/" in body and "secret-notes.txt" in body,
                    f"GET /public/ status={status}",
                ))(*request(base, "/public/"))
            ),
        ),
        run_check(
            "ADMIN_PATH_EXPOSURE",
            "管理路径未限制访问",
            25,
            lambda: (
                (lambda status, body, headers: (
                    status == 200 and "ADMIN_STATUS_TOKEN_2026" in body,
                    f"GET /admin/status.json status={status}",
                ))(*request(base, "/admin/status.json"))
            ),
        ),
        run_check(
            "ACTIVE_UPLOAD_CONTENT",
            "上传目录主动内容可直接执行/访问",
            25,
            lambda: (
                (lambda status, body, headers: (
                    status == 200 and "ACTIVE_UPLOAD_MARKER_2026" in body and "text/html" in headers.get("Content-Type", ""),
                    f"GET /uploads/sample.html status={status} content_type={headers.get('Content-Type','-')}",
                ))(*request(base, "/uploads/sample.html"))
            ),
        ),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Student self-test attack script for the config-hardening exam.")
    parser.add_argument("--base-url", default="http://127.0.0.1:8090")
    parser.add_argument("--json", dest="json_path", default="")
    args = parser.parse_args()

    status, body, _ = request(args.base_url, "/health")
    if status != 200:
        print(f"target health check failed: status={status} body={body[:120]}", file=sys.stderr)
        return 2

    findings = checks(args.base_url)
    total = sum(item.points for item in findings)
    vulnerable = sum(item.points for item in findings if item.attack_succeeded)
    fixed = total - vulnerable
    report = {
        "base_url": args.base_url,
        "script_role": "student_self_test",
        "total_points": total,
        "fixed_points": fixed,
        "vulnerable_points": vulnerable,
        "all_attacks_failed": vulnerable == 0,
        "findings": [item.__dict__ for item in findings],
    }

    for item in findings:
        state = "VULNERABLE" if item.attack_succeeded else "FIXED"
        print(f"[{state}] {item.id} ({item.points} pts) - {item.title}")
        print(f"  evidence: {item.evidence}")
    print(f"fixed_points={fixed} vulnerable_points={vulnerable} all_attacks_failed={vulnerable == 0}")

    if args.json_path:
        with open(args.json_path, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
    return 1 if vulnerable else 0


if __name__ == "__main__":
    raise SystemExit(main())
