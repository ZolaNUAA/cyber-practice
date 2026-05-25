#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  ./setup-kali-exam.sh start          Build and start the vulnerable exam target
  ./setup-kali-exam.sh stop           Stop the exam target
  ./setup-kali-exam.sh reset          Rebuild target and clear generated data
  ./setup-kali-exam.sh restart        Restart target after editing Nginx config
  ./setup-kali-exam.sh student-test   Run the student-visible self-test script
  ./setup-kali-exam.sh final-verify   Run the teacher final verification script
  ./setup-kali-exam.sh portal         Start the web exam portal on 127.0.0.1:8091
  ./setup-kali-exam.sh shell          Start the terminal exam portal
  ./setup-kali-exam.sh attack         Compatibility alias for student-test
  ./setup-kali-exam.sh checksum       Print hashes of verification files
EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing command: $1" >&2
    exit 2
  fi
}

compose() {
  docker compose -f docker-compose.yml "$@"
}

cmd="${1:-}"
case "$cmd" in
  start)
    need_cmd docker
    mkdir -p exam-data/logs exam-data/uploads
    compose up -d --build
    echo "target: http://127.0.0.1:8090"
    ;;
  stop)
    need_cmd docker
    compose down
    ;;
  reset)
    need_cmd docker
    compose down -v --remove-orphans || true
    rm -rf exam-data
    mkdir -p exam-data/logs exam-data/uploads
    compose up -d --build --force-recreate
    echo "target reset: http://127.0.0.1:8090"
    ;;
  restart)
    need_cmd docker
    compose restart exam-gateway
    ;;
  student-test|attack)
    python3 "$ROOT_DIR/student_attack.py" --base-url "${BASE_URL:-http://127.0.0.1:8090}" --json "$ROOT_DIR/latest-student-test.json"
    ;;
  final-verify)
    python3 "$ROOT_DIR/final_verify_runner.py" --base-url "${BASE_URL:-http://127.0.0.1:8090}" --json "$ROOT_DIR/latest-final-report.json"
    ;;
  portal)
    python3 "$ROOT_DIR/portal.py"
    ;;
  shell)
    python3 "$ROOT_DIR/terminal.py"
    ;;
  checksum)
    sha256sum "$ROOT_DIR/student_attack.py" "$ROOT_DIR/final_verify.py.enc" "$ROOT_DIR/final_verify_runner.py" "$ROOT_DIR/portal.py" "$ROOT_DIR/terminal.py" "$ROOT_DIR/grade.py" "$ROOT_DIR/setup-kali-exam.sh" "$ROOT_DIR/docker-compose.yml"
    ;;
  *)
    usage
    exit 1
    ;;
esac
