#!/usr/bin/env python3
import argparse
import getpass
import json
import subprocess
import tempfile
import time
from pathlib import Path


def run_final_verify(root: Path, base_url: str, report_path: Path, password: str) -> dict:
    encrypted = root / "final_verify.py.enc"
    plaintext = root / "final_verify.py"
    temp_path = None
    started = time.monotonic()

    try:
        if encrypted.exists():
            with tempfile.NamedTemporaryFile("w", suffix="-final-verify.py", delete=False) as tmp:
                temp_path = Path(tmp.name)
            decrypt = subprocess.run(
                [
                    "openssl",
                    "enc",
                    "-d",
                    "-aes-256-cbc",
                    "-pbkdf2",
                    "-in",
                    str(encrypted),
                    "-out",
                    str(temp_path),
                    "-pass",
                    "stdin",
                ],
                input=password + "\n",
                cwd=str(root),
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=10,
            )
            if decrypt.returncode != 0:
                elapsed_ms = int((time.monotonic() - started) * 1000)
                return {
                    "cmd": "openssl decrypt final_verify.py.enc",
                    "returncode": decrypt.returncode,
                    "elapsed_ms": elapsed_ms,
                    "output": "教师密码错误，或最终验证脚本密文损坏。\n" + decrypt.stdout[-2000:],
                    "report": None,
                    "ran_at": "",
                }
            script_path = temp_path
        elif plaintext.exists():
            script_path = plaintext
        else:
            elapsed_ms = int((time.monotonic() - started) * 1000)
            return {
                "cmd": "final_verify missing",
                "returncode": 2,
                "elapsed_ms": elapsed_ms,
                "output": "找不到 exam/final_verify.py.enc，也找不到 exam/final_verify.py。",
                "report": None,
                "ran_at": "",
            }

        cmd = ["python3", str(script_path), "--base-url", base_url, "--json", str(report_path)]
        proc = subprocess.run(cmd, cwd=str(root), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        elapsed_ms = int((time.monotonic() - started) * 1000)
        parsed = None
        if report_path.exists():
            try:
                parsed = json.loads(report_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                parsed = None
        return {
            "cmd": "python3 <decrypted-final-verify>",
            "returncode": proc.returncode,
            "elapsed_ms": elapsed_ms,
            "output": proc.stdout[-6000:],
            "report": parsed,
            "ran_at": "",
        }
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)


def main() -> int:
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Run encrypted teacher final verification.")
    parser.add_argument("--base-url", default="http://127.0.0.1:8090")
    parser.add_argument("--json", dest="json_path", default=str(root / "latest-final-report.json"))
    args = parser.parse_args()

    password = getpass.getpass("教师密码：")
    result = run_final_verify(root, args.base_url, Path(args.json_path), password)
    print(result["output"])
    return result["returncode"]


if __name__ == "__main__":
    raise SystemExit(main())
