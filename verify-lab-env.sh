#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; RESET='\033[0m'
ok() { echo -e "  ${GREEN}OK${RESET} $1"; }
warn() { echo -e "  ${YELLOW}WARN${RESET} $1"; }
fail() { echo -e "  ${RED}FAIL${RESET} $1"; }

LABS=(lab01 lab02 lab03 lab04 lab05 lab06 lab07 lab08 lab09 lab10 lab11 lab12)
FAILED=0

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

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    fail "missing command: $1"
    exit 1
  }
}

http_check() {
  local url="$1"
  local name="$2"
  local expected="${3:-}"
  local body

  for _ in $(seq 1 30); do
    body="$(curl -fsS --max-time 3 "$url" 2>/dev/null || true)"
    if [[ -n "$body" ]]; then
      if [[ -z "$expected" || "$body" == *"$expected"* ]]; then
        ok "$name $url"
        return 0
      fi
    fi
    sleep 2
  done

  fail "$name $url"
  return 1
}

tcp_check() {
  local host="$1"
  local port="$2"
  local name="$3"

  for _ in $(seq 1 20); do
    if nc -z "$host" "$port" >/dev/null 2>&1; then
      ok "$name $host:$port"
      return 0
    fi
    sleep 1
  done

  fail "$name $host:$port"
  return 1
}

file_check() {
  local file="$1"
  local name="$2"
  if [[ -s "$file" ]]; then
    ok "$name $file"
  else
    fail "$name $file"
    return 1
  fi
}

verify_lab() {
  local lab="$1"
  case "$lab" in
    lab01)
      http_check http://127.0.0.1:8082/ "nginx" "Nginx Lab" || return 1
      http_check http://127.0.0.1:8086/ "upload-lab" "Upload Lab" || return 1
      http_check http://127.0.0.1:8089/ "traffic-lab" "Traffic Lab" || return 1
      http_check http://127.0.0.1:3000/ "juice-shop" || return 1
      http_check http://127.0.0.1:8080/WebGoat/ "webgoat" || return 1
      tcp_check 127.0.0.1 2222 "ssh-lab" || return 1
      ;;
    lab02)
      http_check http://127.0.0.1:8082/backup/ "backup directory" "db-backup.txt" || return 1
      ;;
    lab03)
      tcp_check 127.0.0.1 2222 "ssh-lab" || return 1
      ;;
    lab04|lab05)
      http_check http://127.0.0.1:3000/ "juice-shop" || return 1
      http_check http://127.0.0.1:8080/WebGoat/ "webgoat" || return 1
      ;;
    lab06)
      http_check http://127.0.0.1:8086/ "upload-lab" "Upload Lab" || return 1
      ;;
    lab07)
      http_check "http://127.0.0.1:8087/?host=127.0.0.1" "cmd-lab" "Command Lab" || return 1
      ;;
    lab08)
      docker exec priv-lab id >/dev/null 2>&1 && ok "priv-lab docker exec" || return 1
      ;;
    lab09)
      http_check http://127.0.0.1:8089/api/status "traffic api" "traffic-lab" || return 1
      ;;
    lab10)
      file_check evidence/ids/eve.json "ids evidence" || return 1
      jq -e '.alert.signature' evidence/ids/eve.json >/dev/null && ok "ids evidence jq parse" || return 1
      ;;
    lab11)
      http_check http://127.0.0.1:8082/ "nginx" "Nginx Lab" || return 1
      http_check http://127.0.0.1:8089/api/status "traffic api" "traffic-lab" || return 1
      file_check evidence/logs/access.log "sample log evidence" || return 1
      ;;
    lab12)
      http_check http://127.0.0.1:8092/ "incident-lab" "Incident Lab" || return 1
      http_check http://127.0.0.1:8082/ "nginx" "Nginx Lab" || return 1
      file_check evidence/incident/auth.log "incident auth evidence" || return 1
      file_check evidence/incident/web-access.log "incident web evidence" || return 1
      ;;
  esac
}

need_cmd docker
need_cmd curl
need_cmd nc
need_cmd jq

"$ROOT_DIR/prepare-lab-data.sh" >/dev/null

for lab in "${LABS[@]}"; do
  profile="$(profile_for_lab "$lab")"
  echo
  echo "==> Verifying $lab ($profile)"

  if ! docker compose --profile "$profile" up -d --build >/dev/null; then
    fail "$lab docker compose startup failed"
    FAILED=$((FAILED + 1))
    docker compose --profile "$profile" down >/dev/null 2>&1 || true
    continue
  fi

  if verify_lab "$lab"; then
    ok "$lab environment ready"
  else
    fail "$lab environment check failed"
    FAILED=$((FAILED + 1))
  fi
  docker compose --profile "$profile" down >/dev/null
done

echo
if [[ "$FAILED" -eq 0 ]]; then
  ok "all 12 lab environments verified"
else
  fail "$FAILED lab(s) failed"
fi

exit "$FAILED"
