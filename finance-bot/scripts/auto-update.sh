#!/usr/bin/env bash
# FinClaw Auto-Update Script
# Syncs your fork with upstream openclaw/openclaw main branch,
# then restarts the gateway if anything changed.
#
# Usage: bash auto-update.sh [--dry-run] [--no-restart]
# Install: see install-updater.sh for systemd timer setup

set -euo pipefail

# Fix 1: scripts/ is 2 levels below repo root (finance-bot/scripts/), not 3
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UPSTREAM_URL="https://github.com/openclaw/openclaw.git"
UPSTREAM_REMOTE="upstream"
MAIN_BRANCH="main"
LOG_FILE="/tmp/finclaw-update.log"
DRY_RUN=false
NO_RESTART=false

for arg in "$@"; do
  case $arg in
    --dry-run)  DRY_RUN=true ;;
    --no-restart) NO_RESTART=true ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== FinClaw Auto-Update Started ==="
log "Repo: $REPO_DIR"

cd "$REPO_DIR"

# ── 1. Ensure upstream remote exists ────────────────────────────────────────
if ! git remote get-url "$UPSTREAM_REMOTE" &>/dev/null; then
  log "Adding upstream remote: $UPSTREAM_URL"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

# ── 2. Fetch upstream ───────────────────────────────────────────────────────
log "Fetching upstream..."
git fetch "$UPSTREAM_REMOTE" "$MAIN_BRANCH" --quiet

# ── 3. Check if anything is new ─────────────────────────────────────────────
NEW_COMMITS=$(git rev-list HEAD.."$UPSTREAM_REMOTE/$MAIN_BRANCH" --count)

if [ "$NEW_COMMITS" -eq 0 ]; then
  log "Already up to date. No changes from upstream."
  exit 0
fi

log "Found $NEW_COMMITS new commit(s) from upstream."
# Fix 2: use process substitution instead of pipe to keep log() in current shell
while read -r line; do
  log "  + $line"
done < <(git log --oneline HEAD.."$UPSTREAM_REMOTE/$MAIN_BRANCH")

if [ "$DRY_RUN" = true ]; then
  log "Dry run — skipping merge and restart."
  exit 0
fi

# ── 4. Merge upstream/main ──────────────────────────────────────────────────
# Safe: finance-bot/ is not in upstream, so merges should always be clean.
# Fix 3: --no-edit and -m are mutually exclusive; use only --no-edit
log "Merging upstream/$MAIN_BRANCH..."
if ! git merge "$UPSTREAM_REMOTE/$MAIN_BRANCH" --no-edit; then
  log "ERROR: Merge conflict detected. Aborting merge — manual intervention needed."
  git merge --abort
  # Fix 4: correct OpenClaw CLI syntax for sending a message
  if command -v openclaw &>/dev/null; then
    openclaw message --channel discord "FinClaw update FAILED: merge conflict with upstream. Manual fix needed in $REPO_DIR" 2>/dev/null || true
  fi
  exit 1
fi

# ── 5. Push updated fork to origin ──────────────────────────────────────────
log "Pushing to origin/$MAIN_BRANCH..."
# Fix 5: handle push failure gracefully instead of exiting hard
if ! git push origin "$MAIN_BRANCH"; then
  log "ERROR: Push to origin failed — fork may have diverged. Manual intervention needed."
  if command -v openclaw &>/dev/null; then
    openclaw message --channel discord "FinClaw update WARNING: push to fork failed. Run: git push origin $MAIN_BRANCH" 2>/dev/null || true
  fi
  exit 1
fi

# ── 6. Restart the gateway ──────────────────────────────────────────────────
if [ "$NO_RESTART" = true ]; then
  log "Skipping restart (--no-restart)."
else
  log "Restarting FinClaw gateway..."
  COMPOSE_FILE="$REPO_DIR/finance-bot/docker-compose.finance.yml"
  if command -v docker &>/dev/null && docker ps --format '{{.Names}}' | grep -q finclaw-gateway; then
    # Fix 6: use docker compose restart to respect compose state
    docker compose -f "$COMPOSE_FILE" restart finclaw-gateway
    log "Docker container restarted."
  elif command -v openclaw &>/dev/null; then
    pkill -f openclaw-gateway 2>/dev/null || true
    sleep 2
    nohup openclaw gateway run --bind loopback --port 18789 --force \
      > /tmp/openclaw-gateway.log 2>&1 &
    log "Gateway restarted (PID: $!)."
  else
    log "WARNING: Could not restart gateway — neither docker nor openclaw CLI found in PATH."
  fi
fi

log "Update complete. $NEW_COMMITS commit(s) applied."
log "=== FinClaw Auto-Update Done ==="
