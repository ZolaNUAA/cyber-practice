#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "[*] Checking Docker"
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed. Run ./install-kali.sh or sudo ./setup-lab-vm.sh first."
  exit 1
fi
docker version --format 'Docker client {{.Client.Version}}, server {{.Server.Version}}'
docker compose version

echo "[*] Checking required tools"
for tool in nmap curl tcpdump tshark jq nc; do
  command -v "$tool" >/dev/null && echo "  ok: $tool" || echo "  missing: $tool"
done

echo "[*] Checking compose config"
docker compose config >/dev/null

echo "[*] Preparing lab data"
./prepare-lab-data.sh >/dev/null

echo "Environment looks ready. Run ./verify-lab-env.sh for a full 12-lab service check."
