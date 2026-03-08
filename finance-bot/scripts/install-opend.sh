#!/usr/bin/env bash
# Install moomoo OpenD as a systemd service on Ubuntu/Linux.
# OpenD is the gateway that connects FinClaw to moomoo's trading API.
#
# Prerequisites:
#   - Ubuntu 22.04+ or CentOS
#   - A moomoo account (sign up at moomoo.com)
#
# Usage: sudo bash finance-bot/scripts/install-opend.sh [--user YOUR_USERNAME]
#
# After install:
#   1. Run: sudo bash finance-bot/scripts/configure-opend.sh
#      (prompts for your moomoo login — only needed once)
#   2. Start: sudo systemctl start moomoo-opend
#   3. Verify: sudo systemctl status moomoo-opend

set -euo pipefail

# ── Must be root ────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo "Error: this script must be run as root. Use: sudo bash $0 $*"
  exit 1
fi

SERVICE_USER="${SUDO_USER:-$(whoami)}"
INSTALL_DIR="/opt/moomoo-opend"
SYSTEMD_DIR="/etc/systemd/system"
OPEND_PORT=11111

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)  SERVICE_USER="$2"; shift 2 ;;
    --port)  OPEND_PORT="$2"; shift 2 ;;
    *)       shift ;;
  esac
done

echo "============================================"
echo "  moomoo OpenD Installer for FinClaw"
echo "============================================"
echo ""
echo "  Install dir : $INSTALL_DIR"
echo "  Service user: $SERVICE_USER"
echo "  API port    : $OPEND_PORT"
echo ""

# ── Install dependencies ───────────────────────────────────────────────────
echo "[1/5] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq libfuse2 curl unzip > /dev/null 2>&1
echo "  Done."

# ── Download OpenD ─────────────────────────────────────────────────────────
echo ""
echo "[2/5] Downloading moomoo OpenD..."
echo ""
echo "  OpenD must be downloaded from the official moomoo site."
echo "  Automatic download is not supported — moomoo requires authentication."
echo ""
echo "  Please download OpenD for Linux (Ubuntu) from:"
echo "    https://www.moomoo.com/us/support/topic3_441"
echo ""
echo "  After downloading, place the archive in: $INSTALL_DIR/"
echo ""

mkdir -p "$INSTALL_DIR"
chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

# Check if OpenD binary already exists (user may have already downloaded)
if [ -f "$INSTALL_DIR/moomoo_OpenD" ] || [ -f "$INSTALL_DIR/FutuOpenD" ]; then
  echo "  OpenD binary found in $INSTALL_DIR — skipping download prompt."
else
  echo "  Waiting for you to place the downloaded archive in $INSTALL_DIR/"
  echo "  Supported formats: .tar.gz, .zip"
  echo ""
  read -rp "  Press Enter once the file is in $INSTALL_DIR (or Ctrl+C to abort)... "

  # Find and extract the archive
  ARCHIVE=$(find "$INSTALL_DIR" -maxdepth 1 -name "*.tar.gz" -o -name "*.zip" 2>/dev/null | head -1)

  if [ -z "$ARCHIVE" ]; then
    echo "  Error: No archive found in $INSTALL_DIR"
    echo "  Download from: https://www.moomoo.com/us/support/topic3_441"
    exit 1
  fi

  echo "  Found: $ARCHIVE"
  echo "  Extracting..."

  if [[ "$ARCHIVE" == *.tar.gz ]]; then
    tar -xzf "$ARCHIVE" -C "$INSTALL_DIR" --strip-components=1
  elif [[ "$ARCHIVE" == *.zip ]]; then
    unzip -o -q "$ARCHIVE" -d "$INSTALL_DIR"
    # Move files out of nested directory if present
    NESTED=$(find "$INSTALL_DIR" -maxdepth 1 -mindepth 1 -type d | head -1)
    if [ -n "$NESTED" ] && [ "$NESTED" != "$INSTALL_DIR" ]; then
      mv "$NESTED"/* "$INSTALL_DIR"/ 2>/dev/null || true
      rmdir "$NESTED" 2>/dev/null || true
    fi
  fi

  echo "  Extracted."
fi

# ── Find and prepare the binary ────────────────────────────────────────────
echo ""
echo "[3/5] Configuring OpenD..."

# OpenD binary may be named FutuOpenD or moomoo_OpenD depending on version
OPEND_BIN=""
for name in moomoo_OpenD FutuOpenD moomooOpenD; do
  if [ -f "$INSTALL_DIR/$name" ]; then
    OPEND_BIN="$INSTALL_DIR/$name"
    break
  fi
done

if [ -z "$OPEND_BIN" ]; then
  echo "  Error: Could not find OpenD binary in $INSTALL_DIR"
  echo "  Expected one of: moomoo_OpenD, FutuOpenD, moomooOpenD"
  echo "  Contents of $INSTALL_DIR:"
  ls -la "$INSTALL_DIR"
  exit 1
fi

chmod +x "$OPEND_BIN"
echo "  Binary: $OPEND_BIN"

# ── Create XML config ──────────────────────────────────────────────────────
# Generate the config file with sane defaults
# Login credentials will be added by configure-opend.sh
cat > "$INSTALL_DIR/FutuOpenD.xml" <<EOF
<?xml version="1.0" encoding="utf-8" ?>
<FutuOpenD>
    <login_account></login_account>
    <login_pwd_md5></login_pwd_md5>
    <login_region>ca</login_region>
    <api_port>${OPEND_PORT}</api_port>
    <lang>en</lang>
    <log_level>warning</log_level>
</FutuOpenD>
EOF

chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
echo "  Config: $INSTALL_DIR/FutuOpenD.xml"

# ── Create systemd service ─────────────────────────────────────────────────
echo ""
echo "[4/5] Creating systemd service..."

cat > "$SYSTEMD_DIR/moomoo-opend.service" <<EOF
[Unit]
Description=moomoo OpenD Gateway — connects FinClaw to moomoo trading API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${OPEND_BIN}
WorkingDirectory=${INSTALL_DIR}
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
User=${SERVICE_USER}
Group=${SERVICE_USER}

# Security hardening
NoNewPrivileges=yes
ProtectHome=read-only
ProtectSystem=strict
ReadWritePaths=${INSTALL_DIR}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable moomoo-opend

echo "  Service created and enabled."

# ── Done ───────────────────────────────────────────────────────────────────
echo ""
echo "[5/5] Installation complete!"
echo ""
echo "============================================"
echo "  Next steps:"
echo "============================================"
echo ""
echo "  1. Configure your moomoo login:"
echo "     sudo bash $(dirname "$0")/configure-opend.sh"
echo ""
echo "  2. Start OpenD:"
echo "     sudo systemctl start moomoo-opend"
echo ""
echo "  3. Check status:"
echo "     sudo systemctl status moomoo-opend"
echo ""
echo "  4. View logs:"
echo "     journalctl -u moomoo-opend -f"
echo ""
echo "  OpenD will listen on port $OPEND_PORT"
echo "  FinClaw's docker-compose is already configured to connect to it."
echo ""
