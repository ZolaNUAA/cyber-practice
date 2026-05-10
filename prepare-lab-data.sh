#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

mkdir -p reports pcaps submit logs
mkdir -p logs/nginx logs/upload logs/traffic logs/incident
mkdir -p evidence/ids evidence/logs evidence/incident

if [[ -f services/ids-lab/eve.json && ! -f evidence/ids/eve.json ]]; then
  cp services/ids-lab/eve.json evidence/ids/eve.json
fi

if [[ -d services/incident-lab/evidence ]]; then
  for f in services/incident-lab/evidence/*; do
    [[ -f "$f" ]] || continue
    target="evidence/incident/$(basename "$f")"
    [[ -f "$target" ]] || cp "$f" "$target"
  done
fi

if [[ -d services/traffic-lab/sample-logs ]]; then
  for f in services/traffic-lab/sample-logs/*; do
    [[ -f "$f" ]] || continue
    target="evidence/logs/$(basename "$f")"
    [[ -f "$target" ]] || cp "$f" "$target"
  done
fi

echo "Lab data prepared."
