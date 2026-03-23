#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script requires root privileges."
  echo "Re-run with: sudo bash scripts/configure_docker_storage.sh"
  exit 1
fi

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
else
  echo "Cannot detect OS. /etc/os-release not found."
  exit 1
fi

if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "This script is intended for Ubuntu hosts. Detected: ${PRETTY_NAME:-unknown}"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed. Run 'make docker-install' first."
  exit 1
fi

if ! command -v containerd >/dev/null 2>&1; then
  echo "containerd is not installed. Run 'make docker-install' first."
  exit 1
fi

SURF_VOLUME_ROOT="${SURF_VOLUME_ROOT:-/data/mlflow_test_storage}"
DATA_ROOT="${DATA_ROOT:-${SURF_VOLUME_ROOT}/mlflow_data}"
DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-${SURF_VOLUME_ROOT}/docker}"
CONTAINERD_ROOT="${CONTAINERD_ROOT:-${SURF_VOLUME_ROOT}/containerd}"
TMPDIR="${TMPDIR:-${SURF_VOLUME_ROOT}/tmp}"

install -d -m 0755 "${SURF_VOLUME_ROOT}" "${TMPDIR}"
install -d -m 0700 "${DOCKER_DATA_ROOT}" "${CONTAINERD_ROOT}"
install -d -m 0755 "${DATA_ROOT}/mlruns" "${DATA_ROOT}/mlartifacts"

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  sudo_group="$(id -gn "${SUDO_USER}")"
  chown -R "${SUDO_USER}:${sudo_group}" "${DATA_ROOT}" "${TMPDIR}"
fi

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

systemctl enable containerd
systemctl enable docker
systemctl start containerd
systemctl start docker

echo "Docker storage configuration complete."
echo "Docker data-root: ${DOCKER_DATA_ROOT}"
echo "containerd root: ${CONTAINERD_ROOT}"
echo "MLflow data root: ${DATA_ROOT}"
