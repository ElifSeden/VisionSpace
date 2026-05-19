#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root or with sudo: sudo bash scripts/install_ubuntu_24_04.sh"
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl gnupg git make python3 python3-venv

install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

mkdir -p data/images/products data/images/rooms data/images/generated
if [[ ! -f .env ]]; then
  cp .env.example .env
fi

echo "Installation complete."
echo "Edit .env, then run: make up && make migrate && make create-qdrant"

