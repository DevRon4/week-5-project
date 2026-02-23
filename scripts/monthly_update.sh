#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/var/log/monthly-updates"
LOG_FILE="$LOG_DIR/update-$(date +%F).log"
mkdir -p "$LOG_DIR"
exec >> "$LOG_FILE" 2>&1

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Must run as root." >&2
  exit 1
fi

. /etc/os-release

case "${ID:-}" in
  amzn|rhel|centos|fedora|rocky|almalinux)
    PM="dnf"
    command -v dnf >/dev/null 2>&1 || PM="yum"
    $PM -y update
    $PM -y upgrade || true
    ;;
  ubuntu|debian)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get upgrade -y
    apt-get autoremove -y
    ;;
  *)
    echo "ERROR: Unsupported OS: ${ID:-unknown}" >&2
    exit 2
    ;;
esac

echo "Monthly update complete: $(date -Is)"
