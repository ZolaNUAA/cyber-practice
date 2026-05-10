#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "[*] Checking Docker"
docker version --format 'Docker client {{.Client.Version}}, server {{.Server.Version}}'
docker compose version

echo "[*] Checking required tools"
for tool in nmap curl tcpdump tshark jq; do
  command -v "$tool" >/dev/null && echo "  ok: $tool" || echo "  missing: $tool"
done

echo "[*] Checking compose config"
docker compose config >/dev/null
echo "Environment looks ready."

