#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Installing Kali packages for the cyber practice lab"
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get update
sudo -E apt-get install -y \
  docker.io docker-compose-plugin \
  curl wget git jq tree vim nano netcat-traditional dnsutils \
  nmap tcpdump wireshark tshark \
  burpsuite zaproxy \
  john hashcat \
  openssl python3 python3-pip

echo "[*] Enabling Docker"
sudo systemctl enable --now docker
sudo usermod -aG docker "${USER}"

echo "[*] Preparing local directories"
mkdir -p "$ROOT_DIR/reports" "$ROOT_DIR/pcaps" "$ROOT_DIR/evidence" "$ROOT_DIR/logs"

echo "[*] Building and pulling lab containers"
cd "$ROOT_DIR"
docker compose pull || true
docker compose build

cat <<'EOF'

Install finished.

If Docker commands fail with a permission error, log out and log back in, or run:
  newgrp docker

Then test with:
  ./check-env.sh
  ./start-lab.sh lab01
EOF
