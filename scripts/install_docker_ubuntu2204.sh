#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "This installer requires root privileges."
  echo "Re-run with: sudo bash scripts/install_docker_ubuntu2204.sh"
  exit 1
fi

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
else
  echo "Cannot detect OS. /etc/os-release not found."
  exit 1
fi

if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "22.04" ]]; then
  echo "This script targets Ubuntu 22.04. Detected: ${PRETTY_NAME:-unknown}"
  exit 1
fi

SURF_VOLUME_ROOT="${SURF_VOLUME_ROOT:-/data/mlflow_test_storage}"
DATA_ROOT="${DATA_ROOT:-${SURF_VOLUME_ROOT}/mlflow_data}"
DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-${SURF_VOLUME_ROOT}/docker}"
CONTAINERD_ROOT="${CONTAINERD_ROOT:-${SURF_VOLUME_ROOT}/containerd}"
TMPDIR="${TMPDIR:-${SURF_VOLUME_ROOT}/tmp}"
APT_CACHE_DIR="${SURF_VOLUME_ROOT}/cache/apt"

install -d -m 0755 "${SURF_VOLUME_ROOT}" "${APT_CACHE_DIR}" "${TMPDIR}"
install -d -m 0700 "${DOCKER_DATA_ROOT}" "${CONTAINERD_ROOT}"
install -d -m 0755 "${DATA_ROOT}/mlruns" "${DATA_ROOT}/mlartifacts"

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  chown -R "${SUDO_USER}:${SUDO_USER}" "${DATA_ROOT}" "${TMPDIR}"
fi

apt_get() {
  apt-get -o Dir::Cache::archives="${APT_CACHE_DIR}" "$@"
}

TMPDIR="${TMPDIR}" apt_get update
TMPDIR="${TMPDIR}" apt_get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu jammy stable" \
  > /etc/apt/sources.list.d/docker.list

TMPDIR="${TMPDIR}" apt_get update
TMPDIR="${TMPDIR}" apt_get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl stop docker.service docker.socket containerd.service 2>/dev/null || true

install -m 0755 -d /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "${DOCKER_DATA_ROOT}"
}
EOF

containerd config default > /etc/containerd/config.toml
sed -i "s#^root = .*#root = \"${CONTAINERD_ROOT}\"#" /etc/containerd/config.toml
sed -i 's#^state = .*#state = "/run/containerd"#' /etc/containerd/config.toml

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  usermod -aG docker "${SUDO_USER}"
  echo "Added ${SUDO_USER} to docker group. Re-login required for group changes."
fi

systemctl enable containerd
systemctl enable docker
systemctl start containerd
systemctl start docker

echo "Docker installation complete."
echo "Docker data-root: ${DOCKER_DATA_ROOT}"
echo "containerd root: ${CONTAINERD_ROOT}"
