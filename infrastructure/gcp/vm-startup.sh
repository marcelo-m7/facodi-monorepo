#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

install_base_packages() {
  apt-get update
  apt-get install -y ca-certificates curl gnupg apt-transport-https
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return 0
  fi

  install_base_packages
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  . /etc/os-release
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian %s stable\n' \
    "$(dpkg --print-architecture)" "$VERSION_CODENAME" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_gcloud() {
  if command -v gcloud >/dev/null 2>&1; then
    return 0
  fi

  install_base_packages
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg
  printf '%s\n' 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' \
    > /etc/apt/sources.list.d/google-cloud-sdk.list

  apt-get update
  apt-get install -y google-cloud-cli
}

install_docker
install_gcloud
systemctl enable --now docker

install -d -m 0755 /opt/facodi
install -d -m 0755 /opt/facodi/infrastructure
install -d -m 0755 /opt/facodi/scripts

cat >/etc/motd <<'EOF'
FACODI staging runtime

Application source code is not cloned on this VM.
Deployments arrive as immutable Artifact Registry images through GitHub Actions.
Create /opt/facodi/.env explicitly before enabling staging deployment.
EOF
