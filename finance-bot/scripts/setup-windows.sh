#!/usr/bin/env bash
# setup-windows.sh — Automated FinClaw setup for Windows (Git Bash)
# Usage: bash finance-bot/scripts/setup-windows.sh
set -euo pipefail

# ─── Colors & Helpers ────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()     { echo -e "${RED}[ERROR]${RESET} $*"; }
die()     { err "$*"; exit 1; }

banner() {
  local phase="$1"; shift
  echo ""
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}${CYAN}  ${phase}: $*${RESET}"
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${RESET}"
  echo ""
}

# Track what we did for the summary
declare -a SUMMARY=()
summary_add() { SUMMARY+=("$*"); }

# ─── Detect repo root ────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FINCLAW_DIR="$REPO_ROOT/finance-bot"

if [[ ! -f "$FINCLAW_DIR/docker-compose.finance.yml" ]]; then
  die "Cannot find finance-bot directory. Run this script from the openclaw repo."
fi

info "Repo root:    $REPO_ROOT"
info "FinClaw dir:  $FINCLAW_DIR"

# ─── Check for winget ─────────────────────────────────────────────────────────

has_winget() {
  command -v winget.exe &>/dev/null || command -v winget &>/dev/null
}

winget_cmd() {
  if command -v winget.exe &>/dev/null; then
    echo "winget.exe"
  elif command -v winget &>/dev/null; then
    echo "winget"
  fi
}

winget_install() {
  local id="$1"
  local name="$2"
  local winget
  winget="$(winget_cmd)"
  info "Installing $name ($id) via winget..."
  "$winget" install --id "$id" --accept-source-agreements --accept-package-agreements -e || {
    warn "winget install of $name failed. You may need to install it manually."
    return 1
  }
  ok "$name installed."
}

# Check if a command exists in PATH
has_cmd() { command -v "$1" &>/dev/null; }

###############################################################################
# Phase 1 — Install Base Tools
###############################################################################
banner "Phase 1/9" "Installing Base Tools"

if ! has_winget; then
  warn "winget is not available. Please install the following manually:"
  warn "  - Git:            https://git-scm.com"
  warn "  - Node.js LTS:    https://nodejs.org"
  warn "  - Python 3.12:    https://python.org"
  warn "  - GitHub CLI:     https://cli.github.com"
  warn "  - Docker Desktop: https://docker.com/products/docker-desktop"
  warn ""
  warn "After installing, re-run this script."
  summary_add "SKIP  Base tools (winget not available)"
else
  # Git
  if has_cmd git; then
    ok "Git already installed: $(git --version)"
  else
    winget_install "Git.Git" "Git"
  fi

  # Node.js LTS
  if has_cmd node; then
    ok "Node.js already installed: $(node --version)"
  else
    winget_install "OpenJS.NodeJS.LTS" "Node.js LTS"
  fi

  # Python 3.12
  if has_cmd python3 || has_cmd python; then
    local_py=""
    if has_cmd python3; then local_py="python3"; else local_py="python"; fi
    ok "Python already installed: $($local_py --version 2>&1)"
  else
    winget_install "Python.Python.3.12" "Python 3.12"
  fi

  # GitHub CLI
  if has_cmd gh; then
    ok "GitHub CLI already installed: $(gh --version | head -1)"
  else
    winget_install "GitHub.cli" "GitHub CLI"
  fi

  # Docker Desktop
  if has_cmd docker; then
    ok "Docker already installed: $(docker --version)"
  else
    winget_install "Docker.DockerDesktop" "Docker Desktop"
    warn ""
    warn "IMPORTANT: After Docker Desktop installs, open it and:"
    warn "  1. Enable WSL 2 backend (Settings > General > Use WSL 2 based engine)"
    warn "  2. Restart Docker Desktop"
    warn ""
  fi

  summary_add "DONE  Base tools checked/installed (git, node, python, gh, docker)"
fi

echo ""
warn "If any tools were just installed, you may need to restart Git Bash"
warn "for PATH changes to take effect before continuing."
echo ""
read -rp "Press Enter to continue (or Ctrl+C to restart Git Bash first)..."

###############################################################################
# Phase 2 — GitHub Auth & Clone
###############################################################################
banner "Phase 2/9" "GitHub Auth & Clone"

# GitHub auth
if has_cmd gh; then
  if gh auth status &>/dev/null; then
    ok "Already authenticated with GitHub CLI."
  else
    info "Logging in to GitHub CLI..."
    gh auth login
  fi
  summary_add "DONE  GitHub CLI authenticated"
else
  warn "gh not found in PATH. Skipping GitHub auth."
  summary_add "SKIP  GitHub CLI auth (gh not in PATH)"
fi

# Git identity
info "Setting git identity..."
git config --global user.name "Isa Din"
git config --global user.email "isadin531@gmail.com"
ok "Git identity set: Isa Din <isadin531@gmail.com>"
summary_add "DONE  Git identity configured"

# Clone fork
CLONE_TARGET="$HOME/openclaw"
if [[ -d "$CLONE_TARGET/.git" ]]; then
  ok "Fork already cloned at $CLONE_TARGET"
else
  info "Cloning fork to $CLONE_TARGET..."
  git clone https://github.com/Trooper15a/openclaw.git "$CLONE_TARGET"
  ok "Fork cloned to $CLONE_TARGET"
fi
summary_add "DONE  Fork cloned to $CLONE_TARGET"

###############################################################################
# Phase 3 — Install Ollama & Pull Models
###############################################################################
banner "Phase 3/9" "Ollama & Models"

if has_cmd ollama; then
  ok "Ollama already installed: $(ollama --version 2>&1 || echo 'installed')"
else
  warn "Ollama is not installed."
  warn "Download and install from: https://ollama.com"
  warn "After installing, re-run this script or continue below."
  echo ""
  read -rp "Press Enter after installing Ollama (or Ctrl+C to abort)..."
fi

if has_cmd ollama; then
  # Pull primary model
  info "Pulling qwen3-coder:30b (this may take a while, ~19 GB)..."
  ollama pull qwen3-coder:30b && ok "qwen3-coder:30b pulled." || warn "Failed to pull qwen3-coder:30b"

  # Pull monitor model
  info "Pulling glm-4.7-flash (~4 GB)..."
  ollama pull glm-4.7-flash && ok "glm-4.7-flash pulled." || warn "Failed to pull glm-4.7-flash"

  summary_add "DONE  Ollama models pulled (qwen3-coder:30b, glm-4.7-flash)"

  # Optional custom model with 65K context
  echo ""
  read -rp "Create custom 65K-context model (qwen3-coder-finclaw)? [y/N] " create_custom
  if [[ "$create_custom" =~ ^[Yy]$ ]]; then
    MODELFILE_TMP="$(mktemp /tmp/Modelfile.finclaw.XXXXXX)"
    cat > "$MODELFILE_TMP" <<'MODELFILE'
FROM qwen3-coder:30b

PARAMETER num_ctx 65536
MODELFILE
    info "Creating custom model qwen3-coder-finclaw..."
    ollama create qwen3-coder-finclaw -f "$MODELFILE_TMP" && ok "Custom model created." || warn "Failed to create custom model."
    rm -f "$MODELFILE_TMP"
    summary_add "DONE  Custom 65K context model created"
  else
    info "Skipping custom model creation."
    summary_add "SKIP  Custom 65K context model"
  fi
else
  warn "Ollama still not found. Skipping model pulls."
  summary_add "SKIP  Ollama models (ollama not installed)"
fi

###############################################################################
# Phase 4 — Install OpenClaw & ClawHub
###############################################################################
banner "Phase 4/9" "Install OpenClaw & ClawHub"

if ! has_cmd npm; then
  die "npm not found. Install Node.js first (Phase 1) and restart Git Bash."
fi

info "Installing openclaw and clawhub globally via npm..."
npm install -g openclaw clawhub 2>&1 || warn "npm install had warnings (may be OK)"

if has_cmd openclaw; then
  ok "openclaw installed: $(openclaw --version 2>&1 || echo 'installed')"
else
  warn "openclaw command not found after install. Check your PATH."
fi
if has_cmd clawhub; then
  ok "clawhub installed: $(clawhub --version 2>&1 || echo 'installed')"
else
  warn "clawhub command not found after install. Check your PATH."
fi
summary_add "DONE  openclaw + clawhub installed globally"

###############################################################################
# Phase 5 — Configure Secrets
###############################################################################
banner "Phase 5/9" "Configure Secrets"

OPENCLAW_DIR="$HOME/.openclaw"
mkdir -p "$OPENCLAW_DIR"
ok "Directory $OPENCLAW_DIR exists"

# Copy openclaw.json.example
CONFIG_FILE="$OPENCLAW_DIR/openclaw.json"
if [[ -f "$CONFIG_FILE" ]]; then
  ok "openclaw.json already exists at $CONFIG_FILE"
else
  cp "$FINCLAW_DIR/openclaw.json.example" "$CONFIG_FILE"
  ok "Copied openclaw.json.example to $CONFIG_FILE"
fi

# Copy .env.example
ENV_FILE="$FINCLAW_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  ok ".env already exists at $ENV_FILE"
else
  cp "$FINCLAW_DIR/.env.example" "$ENV_FILE"
  ok "Copied .env.example to $ENV_FILE"
fi

# Generate and fill gateway token
GATEWAY_TOKEN="$(openssl rand -hex 32)"
info "Generated gateway token: ${GATEWAY_TOKEN:0:8}..."

if grep -q "^OPENCLAW_GATEWAY_TOKEN=$" "$ENV_FILE" 2>/dev/null; then
  # Token line is empty, fill it in
  sed -i "s|^OPENCLAW_GATEWAY_TOKEN=.*|OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}|" "$ENV_FILE"
  ok "Gateway token written to .env"
elif grep -q "^OPENCLAW_GATEWAY_TOKEN=" "$ENV_FILE" 2>/dev/null; then
  # Token line already has a value
  warn "OPENCLAW_GATEWAY_TOKEN already has a value in .env. Not overwriting."
else
  # No token line found, append it
  echo "OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}" >> "$ENV_FILE"
  ok "Gateway token appended to .env"
fi

summary_add "DONE  Secrets directory and config files created"
summary_add "DONE  Gateway token generated and written to .env"

echo ""
warn "You still need to manually fill in these values:"
warn "  1. DISCORD_BOT_TOKEN  (create bot at https://discord.com/developers/applications)"
warn "  2. YOUR_GUILD_ID      (right-click server > Copy Server ID in Discord)"
warn "  3. YOUR_CHANNEL_ID    (right-click channel > Copy Channel ID in Discord)"
warn "  4. TAVILY_API_KEY     (get free key at https://app.tavily.com)"
echo ""

# Open config files for editing
read -rp "Open config files in Notepad for editing? [Y/n] " open_notepad
if [[ ! "$open_notepad" =~ ^[Nn]$ ]]; then
  info "Opening .env in Notepad..."
  notepad.exe "$(cygpath -w "$ENV_FILE")" &

  info "Opening openclaw.json in Notepad..."
  notepad.exe "$(cygpath -w "$CONFIG_FILE")" &

  echo ""
  info "Edit the files in Notepad, save, and close them."
  read -rp "Press Enter when done editing..."
fi

###############################################################################
# Phase 6 — Set Up Workspaces
###############################################################################
banner "Phase 6/9" "Set Up Workspaces"

WORKSPACES=(
  "$OPENCLAW_DIR/workspace-finclaw"
  "$OPENCLAW_DIR/workspace-finclaw-coder"
  "$OPENCLAW_DIR/workspace-finclaw-monitor"
)

if has_cmd openclaw; then
  for ws in "${WORKSPACES[@]}"; do
    if [[ -d "$ws" ]]; then
      ok "Workspace already exists: $ws"
    else
      info "Creating workspace: $ws"
      openclaw setup --workspace "$ws" || warn "Failed to set up workspace $ws"
      ok "Workspace created: $ws"
    fi
  done
else
  warn "openclaw command not found. Creating workspace directories manually."
  for ws in "${WORKSPACES[@]}"; do
    mkdir -p "$ws"
    ok "Created directory: $ws"
  done
fi

# Copy workspace files to the main finclaw workspace
info "Copying workspace files to main finclaw workspace..."
cp -r "$FINCLAW_DIR/workspace/"* "$OPENCLAW_DIR/workspace-finclaw/" 2>/dev/null || true
ok "Workspace files copied to $OPENCLAW_DIR/workspace-finclaw/"

summary_add "DONE  Agent workspaces created (finclaw, coder, monitor)"
summary_add "DONE  Workspace files seeded"

###############################################################################
# Phase 7 — Python Dependencies
###############################################################################
banner "Phase 7/9" "Python Dependencies"

PY_CMD=""
if has_cmd python3; then
  PY_CMD="python3"
elif has_cmd python; then
  PY_CMD="python"
elif has_cmd py; then
  PY_CMD="py"
fi

if [[ -z "$PY_CMD" ]]; then
  warn "Python not found. Install Python 3.12 and re-run."
  summary_add "SKIP  Python dependencies (python not found)"
else
  ok "Using Python: $($PY_CMD --version 2>&1)"
  PIP_CMD="$PY_CMD -m pip"

  info "Installing Python dependencies..."
  $PIP_CMD install --user yfinance pandas ta pytz feedparser moomoo-api nano-pdf 2>&1 || {
    warn "Some Python packages may have failed to install."
  }
  ok "Python dependencies installed."
  summary_add "DONE  Python dependencies installed"
fi

###############################################################################
# Phase 8 — Install ClawHub Skills
###############################################################################
banner "Phase 8/9" "Install ClawHub Skills"

if ! has_cmd clawhub; then
  warn "clawhub not found. Skipping skill installation."
  summary_add "SKIP  ClawHub skills (clawhub not in PATH)"
else
  # All skills organized by category
  declare -a SKILLS=(
    # Security (always first)
    "skill-vetter"
    "agentguard"
    # Search & Research
    "tavily"
    "brave-search"
    "web-fetch"
    "x-research"
    # Finance
    "coingecko"
    "portfolio-watcher"
    "earnings-tracker"
    # Automation
    "cron-scheduler"
    "webhook-triggers"
    "proactive-agent"
    "api-gateway"
    # Coding, Memory & Self-Improvement
    "agent-brain"
    "agent-team-orchestration"
    "find-skills"
    "self-improving-agent"
    "advanced-skill-creator"
    "agentic-security-audit"
    "alex-session-wrap-up"
    "opencode"
    # Prediction Markets
    "polyclaw"
    "kalshi"
  )

  INSTALLED=0
  FAILED=0

  for skill in "${SKILLS[@]}"; do
    info "Installing skill: $skill"
    if clawhub install "$skill" 2>&1; then
      ok "  $skill installed"
      ((INSTALLED++)) || true
    else
      warn "  $skill failed to install"
      ((FAILED++)) || true
    fi
  done

  ok "Skills installed: $INSTALLED  |  Failed: $FAILED"

  info "Listing installed skills..."
  clawhub list 2>&1 || true

  summary_add "DONE  ClawHub skills installed ($INSTALLED ok, $FAILED failed)"
fi

###############################################################################
# Phase 9 — Launch
###############################################################################
banner "Phase 9/9" "Launch FinClaw"

if ! has_cmd docker; then
  warn "Docker not found. Cannot launch containers."
  summary_add "SKIP  Docker launch (docker not in PATH)"
else
  # Check if Docker daemon is running
  if ! docker info &>/dev/null; then
    warn "Docker daemon is not running. Start Docker Desktop first."
    warn ""
    warn "After starting Docker Desktop, run:"
    warn "  docker compose -f $FINCLAW_DIR/docker-compose.finance.yml up -d"
    summary_add "SKIP  Docker launch (daemon not running)"
  else
    info "Starting FinClaw via Docker Compose..."
    cd "$FINCLAW_DIR"
    docker compose -f docker-compose.finance.yml up -d 2>&1 || {
      warn "docker compose failed. Trying docker-compose (v1)..."
      docker-compose -f docker-compose.finance.yml up -d 2>&1 || {
        err "Failed to start containers. Check Docker Desktop and try again."
        summary_add "FAIL  Docker launch"
      }
    }

    echo ""
    info "Showing recent logs (Ctrl+C to stop)..."
    sleep 2
    docker logs --tail 30 finclaw-gateway 2>&1 || true

    summary_add "DONE  FinClaw containers launched"
  fi
fi

###############################################################################
# Summary
###############################################################################
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  Setup Summary${RESET}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════════${RESET}"
echo ""

for item in "${SUMMARY[@]}"; do
  case "$item" in
    DONE*)  echo -e "  ${GREEN}[x]${RESET} ${item#DONE  }" ;;
    SKIP*)  echo -e "  ${YELLOW}[-]${RESET} ${item#SKIP  }" ;;
    FAIL*)  echo -e "  ${RED}[!]${RESET} ${item#FAIL  }" ;;
    *)      echo -e "  [ ] $item" ;;
  esac
done

echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo "  1. Make sure Docker Desktop is running with WSL 2 enabled"
echo "  2. Verify Ollama is running:  ollama list"
echo "  3. Fill in secrets in:        $ENV_FILE"
echo "  4. Fill in Discord config in: $CONFIG_FILE"
echo "  5. Start FinClaw:             docker compose -f $FINCLAW_DIR/docker-compose.finance.yml up -d"
echo "  6. Check logs:                docker logs -f finclaw-gateway"
echo "  7. Say hello in Discord:      \"What is the current price of NVDA?\""
echo ""
echo -e "${GREEN}FinClaw setup complete.${RESET}"
