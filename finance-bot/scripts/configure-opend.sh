#!/usr/bin/env bash
# Configure moomoo OpenD with your account credentials.
# Run this once after install-opend.sh, or again to update credentials.
#
# Usage: sudo bash finance-bot/scripts/configure-opend.sh
#
# This script:
#   1. Prompts for your moomoo account (email/phone)
#   2. Prompts for your password (MD5-hashed, never stored in plain text)
#   3. Updates FutuOpenD.xml
#   4. Restarts the OpenD service

set -euo pipefail

INSTALL_DIR="/opt/moomoo-opend"
CONFIG_FILE="$INSTALL_DIR/FutuOpenD.xml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found."
  echo "Run install-opend.sh first."
  exit 1
fi

echo "============================================"
echo "  moomoo OpenD — Account Configuration"
echo "============================================"
echo ""
echo "  Your credentials are MD5-hashed and stored"
echo "  locally in $CONFIG_FILE only."
echo "  They are never sent anywhere except moomoo's"
echo "  own servers via OpenD."
echo ""

# ── Get account ────────────────────────────────────────────────────────────
read -rp "  moomoo account (email or phone): " MOOMOO_ACCOUNT

if [ -z "$MOOMOO_ACCOUNT" ]; then
  echo "  Error: Account cannot be empty."
  exit 1
fi

# ── Get password and MD5 hash it ───────────────────────────────────────────
echo ""
read -rsp "  moomoo password (hidden): " MOOMOO_PWD
echo ""

if [ -z "$MOOMOO_PWD" ]; then
  echo "  Error: Password cannot be empty."
  exit 1
fi

# MD5 hash the password — OpenD expects login_pwd_md5
PWD_MD5=$(echo -n "$MOOMOO_PWD" | md5sum | awk '{print $1}')

# Clear the plaintext password from memory
MOOMOO_PWD=""

echo ""
echo "  Account : $MOOMOO_ACCOUNT"
echo "  Password: (MD5 hashed)"
echo ""

# ── Update the XML config ─────────────────────────────────────────────────
# Escape special characters in account input to prevent sed injection
escaped_account=$(printf '%s\n' "$MOOMOO_ACCOUNT" | sed -e 's/[\/&|]/\\&/g')
escaped_md5=$(printf '%s\n' "$PWD_MD5" | sed -e 's/[\/&|]/\\&/g')

sed -i "s|<login_account>.*</login_account>|<login_account>${escaped_account}</login_account>|" "$CONFIG_FILE"
sed -i "s|<login_pwd_md5>.*</login_pwd_md5>|<login_pwd_md5>${escaped_md5}</login_pwd_md5>|" "$CONFIG_FILE"

echo "  Config updated: $CONFIG_FILE"

# ── Restrict file permissions ──────────────────────────────────────────────
chmod 600 "$CONFIG_FILE"
echo "  Permissions set to 600 (owner-only read/write)"

# ── Restart OpenD if running ───────────────────────────────────────────────
if systemctl is-active --quiet moomoo-opend 2>/dev/null; then
  echo ""
  echo "  Restarting OpenD service..."
  systemctl restart moomoo-opend
  sleep 3
  if systemctl is-active --quiet moomoo-opend; then
    echo "  OpenD is running."
  else
    echo "  Warning: OpenD failed to start. Check logs:"
    echo "    journalctl -u moomoo-opend -n 20"
  fi
else
  echo ""
  echo "  OpenD service is not running. Start it with:"
  echo "    sudo systemctl start moomoo-opend"
fi

echo ""
echo "  Done. OpenD is configured for account: $MOOMOO_ACCOUNT"
echo ""
