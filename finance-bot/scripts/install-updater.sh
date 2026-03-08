#!/usr/bin/env bash
# Install the FinClaw auto-updater as a systemd timer on Ubuntu/Linux.
# Run once on the dedicated PC after cloning your fork.
#
# Usage: sudo bash finance-bot/scripts/install-updater.sh [--user YOUR_USERNAME] [--repo /path/to/openclaw]

set -euo pipefail

# Fix 7: must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: this script must be run as root. Use: sudo bash $0 $*"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Fix 8: fall back to whoami if SUDO_USER is unset (e.g. direct root login)
SERVICE_USER="${SUDO_USER:-$(whoami)}"
SYSTEMD_DIR="/etc/systemd/system"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)  SERVICE_USER="$2"; shift 2 ;;
    --repo)  REPO_DIR="$2"; shift 2 ;;
    *)       shift ;;
  esac
done

# Fix 9: verify auto-update.sh exists before proceeding
UPDATE_SCRIPT="$REPO_DIR/finance-bot/scripts/auto-update.sh"
if [ ! -f "$UPDATE_SCRIPT" ]; then
  echo "Error: auto-update.sh not found at $UPDATE_SCRIPT"
  echo "Make sure --repo points to the root of your openclaw fork."
  exit 1
fi

echo "Installing FinClaw auto-updater..."
echo "  Repo:   $REPO_DIR"
echo "  User:   $SERVICE_USER"

# ── Write service file ───────────────────────────────────────────────────────
cat > "$SYSTEMD_DIR/finclaw-updater.service" <<EOF
[Unit]
Description=FinClaw Auto-Update — sync fork with upstream openclaw/openclaw
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash ${REPO_DIR}/finance-bot/scripts/auto-update.sh
StandardOutput=journal
StandardError=journal
User=${SERVICE_USER}
Group=${SERVICE_USER}

[Install]
WantedBy=multi-user.target
EOF

# ── Write timer file ─────────────────────────────────────────────────────────
cp "$(dirname "${BASH_SOURCE[0]}")/finclaw-updater.timer" "$SYSTEMD_DIR/finclaw-updater.timer"

# ── Enable and start ─────────────────────────────────────────────────────────
systemctl daemon-reload
systemctl enable finclaw-updater.timer
systemctl start finclaw-updater.timer

echo ""
echo "Auto-updater installed."
echo ""
echo "Useful commands:"
echo "  systemctl status finclaw-updater.timer   # check timer status"
echo "  systemctl list-timers finclaw-updater*   # see next run time"
echo "  journalctl -u finclaw-updater.service    # view update logs"
echo "  bash $REPO_DIR/finance-bot/scripts/auto-update.sh --dry-run  # test without applying"
