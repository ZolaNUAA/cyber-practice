#!/usr/bin/env bash
set -euo pipefail

LAB="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [[ -z "$LAB" ]]; then
  echo "Usage: ./reset-lab.sh lab01|lab02|...|lab12"
  exit 1
fi

echo "[*] Resetting containers"
docker compose down -v --remove-orphans

echo "[*] Resetting local evidence directories"
mkdir -p evidence/ids evidence/logs evidence/incident pcaps reports logs
find evidence/ids evidence/logs evidence/incident pcaps reports logs -type f -delete

mkdir -p evidence/ids evidence/logs evidence/incident
cp services/ids-lab/eve.json evidence/ids/eve.json
cp services/incident-lab/evidence/* evidence/incident/ 2>/dev/null || true
cp services/traffic-lab/sample-logs/* evidence/logs/ 2>/dev/null || true

echo "[*] Starting requested lab"
"$ROOT_DIR/start-lab.sh" "$LAB"

