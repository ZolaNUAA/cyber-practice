#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALI_MIRROR="${KALI_MIRROR:-http://mirrors.ustc.edu.cn/kali}"
CHINA_MIRRORS="${CHINA_MIRRORS:-true}"

echo "[*] Installing Kali packages for the cyber practice lab"
export DEBIAN_FRONTEND=noninteractive

if [[ "$CHINA_MIRRORS" == "true" ]]; then
  echo "[*] Switching Kali apt source to $KALI_MIRROR"
  sudo cp /etc/apt/sources.list /etc/apt/sources.list.cyber-practice.bak 2>/dev/null || true
  printf 'deb %s kali-rolling main contrib non-free non-free-firmware\n' "$KALI_MIRROR" | sudo tee /etc/apt/sources.list >/dev/null
  sudo mkdir -p /etc/apt/apt.conf.d
  printf '%s\n' \
    'Acquire::Retries "3";' \
    'Acquire::http::Timeout "20";' \
    'Acquire::https::Timeout "20";' | sudo tee /etc/apt/apt.conf.d/99cyber-practice-retries >/dev/null
fi

sudo -E apt-get update
sudo -E apt-get install -y \
  docker.io docker-compose-plugin \
  curl wget git jq tree vim nano netcat-traditional dnsutils \
  nmap tcpdump wireshark tshark \
  burpsuite zaproxy \
  john hashcat \
  openssl python3 python3-pip

echo "[*] Enabling Docker"
if [[ "$CHINA_MIRRORS" == "true" ]]; then
  echo "[*] Configuring Docker registry mirrors"
  sudo mkdir -p /etc/docker
  sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.cyber-practice.bak 2>/dev/null || true
  sudo tee /etc/docker/daemon.json >/dev/null <<'DOCKERJSON'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://dockerproxy.cn"
  ],
  "max-concurrent-downloads": 6
}
DOCKERJSON
fi
sudo systemctl enable --now docker
sudo systemctl restart docker || true
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
