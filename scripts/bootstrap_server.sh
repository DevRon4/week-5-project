#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log/server-bootstrap"
LOG_FILE="$LOG_DIR/bootstrap-$(date +%F).log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run with sudo/root." >&2
  exit 1
fi

COMMON_PKGS=(git wget unzip curl vim nano htop net-tools tree zip python3 tar)

install_rhel() {
  local PM="dnf"
  command -v dnf >/dev/null 2>&1 || PM="yum"
  $PM -y update
  $PM -y install "${COMMON_PKGS[@]}"
  $PM -y upgrade || true
}

install_ubuntu() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y "${COMMON_PKGS[@]}"
  apt-get autoremove -y
}

. /etc/os-release
case "${ID:-}" in
  amzn|rhel|centos|fedora|rocky|almalinux) install_rhel ;;
  ubuntu|debian) install_ubuntu ;;
  *) echo "Unsupported OS: ${ID:-unknown}" >&2; exit 2 ;;
esac

echo "Bootstrap complete. Log: $LOG_FILE"
