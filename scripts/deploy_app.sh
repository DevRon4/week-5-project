#!/usr/bin/env bash
set -euo pipefail

# ---- CONFIG (edit these once for your environment) ----
APP_DIR="/opt/week-5-project"      # where your repo lives on the server
BRANCH="main"                      # branch to deploy
SERVICE_NAME="nginx"               # change if your app uses a different systemd service
DEPLOY_LOG="/var/log/deployments/week5-deploy.log"

# Dependency mode: node | python | none
DEP_MODE="none"
NODE_INSTALL_CMD="npm ci"
PY_REQUIREMENTS="requirements.txt"
# ------------------------------------------------------

LOCK_FILE="/tmp/week5-deploy.lock"
TS="$(date +%F_%H%M%S)"
BACKUP_DIR="/opt/backups/week-5-project/$TS"

mkdir -p "$(dirname "$DEPLOY_LOG")"
exec > >(tee -a "$DEPLOY_LOG") 2>&1

echo "=== DEPLOY START $(date -Is) ==="
echo "Repo dir: $APP_DIR | Branch: $BRANCH | Service: $SERVICE_NAME | Mode: $DEP_MODE"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run with sudo/root (needed to restart services)." >&2
  exit 1
fi

if [[ -e "$LOCK_FILE" ]]; then
  echo "ERROR: Deploy lock exists ($LOCK_FILE). Another deploy may be running." >&2
  exit 2
fi
trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

command -v git >/dev/null 2>&1 || { echo "ERROR: git not installed"; exit 3; }
command -v rsync >/dev/null 2>&1 || { echo "ERROR: rsync not installed"; exit 3; }
[[ -d "$APP_DIR/.git" ]] || { echo "ERROR: $APP_DIR is not a git repo"; exit 4; }

echo "[INFO] Backup current release to: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
rsync -a --delete --exclude ".git" "$APP_DIR/" "$BACKUP_DIR/"

echo "[INFO] Pull latest code..."
cd "$APP_DIR"
git fetch --all --prune
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

case "$DEP_MODE" in
  node)
    command -v node >/dev/null 2>&1 || { echo "ERROR: node not installed"; exit 5; }
    command -v npm >/dev/null 2>&1 || { echo "ERROR: npm not installed"; exit 5; }
    echo "[INFO] Installing Node deps: $NODE_INSTALL_CMD"
    $NODE_INSTALL_CMD
    ;;
  python)
    command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not installed"; exit 6; }
    command -v pip3 >/dev/null 2>&1 || { echo "ERROR: pip3 not installed"; exit 6; }
    if [[ -f "$PY_REQUIREMENTS" ]]; then
      echo "[INFO] Installing Python deps from $PY_REQUIREMENTS"
      pip3 install -r "$PY_REQUIREMENTS"
    else
      echo "[WARN] $PY_REQUIREMENTS not found. Skipping."
    fi
    ;;
  none) echo "[INFO] No dependency step (DEP_MODE=none)." ;;
  *) echo "ERROR: Unknown DEP_MODE=$DEP_MODE" >&2; exit 7 ;;
esac

echo "[INFO] Restarting service: $SERVICE_NAME"
systemctl daemon-reload || true
systemctl restart "$SERVICE_NAME"

if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "[OK] Service is active."
else
  echo "[ERROR] Service failed after deploy. Check: systemctl status $SERVICE_NAME" >&2
  echo "[INFO] Rollback backup exists at: $BACKUP_DIR"
  exit 8
fi

echo "=== DEPLOY SUCCESS $(date -Is) ==="
echo "Backup saved at: $BACKUP_DIR"
