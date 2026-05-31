#!/usr/bin/env bash
set -euo pipefail

LAB="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

usage() {
  echo "Usage: ./start-lab.sh lab01|lab02|...|lab12"
}

profile_for_lab() {
  case "$1" in
    lab01) echo "recon" ;;
    lab02) echo "info-leak" ;;
    lab03) echo "auth" ;;
    lab04) echo "sqli" ;;
    lab05) echo "xss" ;;
    lab06) echo "upload" ;;
    lab07) echo "cmd" ;;
    lab08) echo "priv" ;;
    lab09) echo "traffic" ;;
    lab10) echo "ids" ;;
    lab11) echo "logs" ;;
    lab12) echo "incident" ;;
    *) return 1 ;;
  esac
}

if [[ -z "$LAB" ]]; then usage; exit 1; fi
PROFILE="$(profile_for_lab "$LAB")" || { usage; exit 1; }

"$ROOT_DIR/prepare-lab-data.sh" >/dev/null

echo "[*] Starting $LAB ($PROFILE)"
docker compose --profile "$PROFILE" up -d --build

echo
echo "Safety boundary:"
echo "  Allowed targets: 127.0.0.1, localhost, and the Docker containers started by this course."
echo "  Do not scan campus networks, classmates' machines, public IPs, real websites, or any non-authorized target."
echo "  Do not replace course command targets with external addresses."
echo
echo "Lab manual:"
find "$ROOT_DIR/labs" -maxdepth 2 -type f -name "README.md" | sort | grep "$LAB" || true
echo
case "$LAB" in
  lab01) echo "Targets: http://127.0.0.1:8082, http://127.0.0.1:8086, http://127.0.0.1:8089, http://127.0.0.1:3000, http://127.0.0.1:8080/WebGoat, ssh student@127.0.0.1 -p 2222" ;;
  lab02) echo "Target: http://127.0.0.1:8082" ;;
  lab03) echo "Target: ssh student@127.0.0.1 -p 2222 ; password Student123" ;;
  lab04) echo "Target: http://127.0.0.1:3000 and http://127.0.0.1:8080/WebGoat" ;;
  lab05) echo "Target: http://127.0.0.1:3000 and http://127.0.0.1:8080/WebGoat" ;;
  lab06) echo "Target: http://127.0.0.1:8086" ;;
  lab07) echo "Target: http://127.0.0.1:8087" ;;
  lab08) echo "Target: docker exec -it priv-lab bash" ;;
  lab09) echo "Target: http://127.0.0.1:8089 ; capture on loopback or Docker bridge" ;;
  lab10) echo "Evidence: evidence/ids/eve.json" ;;
  lab11) echo "Evidence: evidence/logs/" ;;
  lab12) echo "Target: http://127.0.0.1:8092 ; evidence/incident/" ;;
esac
