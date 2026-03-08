# FinClaw — Finance Bot for OpenClaw

FinClaw is a self-hosted, multi-agent finance assistant built on the [OpenClaw](https://github.com/openclaw/openclaw) autonomous AI agent platform. It runs entirely on local hardware using Ollama LLMs — no cloud subscription required. FinClaw can answer market questions, fetch live prices, screen stocks and crypto, write and execute Python finance scripts, monitor a watchlist in the background, and optionally connect to moomoo for paper or live trading. You interact with it over Discord or Telegram.

---

## Architecture

```
You (Discord / Telegram)
         |
         v
+---------------------+
|   FinClaw           |  <-- finclaw agent (qwen3-coder:30b)
|   Orchestrator      |      Main entry point. Understands your
|   (finclaw)         |      intent and delegates to subagents.
+---------------------+
         |
    +---------+-----------+
    |                     |
    v                     v
+-------------------+  +----------------------+
| FinClaw Coder     |  | FinClaw Monitor      |
| (coder)           |  | (monitor)            |
| qwen3-coder:30b   |  | glm-4.7-flash        |
|                   |  |                      |
| Builds scripts,   |  | Background watcher.  |
| apps, data pipel- |  | Runs cron jobs for   |
| ines, and ad-hoc  |  | price alerts, port-  |
| finance tools in  |  | folio snapshots, and |
| a Docker sandbox. |  | daily summaries.     |
+-------------------+  +----------------------+
         |
    (Docker sandbox)
    python3, yfinance, pandas,
    ta, matplotlib, feedparser
```

---

## Prerequisites

- **Ollama** installed and running on the host machine
  - Model: `qwen3-coder:30b` (primary, ~19 GB, 256K context)
  - Model: `glm-4.7-flash` (fallback/monitor, ~4 GB)
- **Docker** and **Docker Compose** installed
- A **Discord bot token** (or Telegram bot token) — see setup step 2
- **Tavily API key** (free) — required for news and research. Get at https://app.tavily.com
- **Python 3** + pip (used inside the Docker sandbox; no host install needed)
- At least **24 GB free RAM** for running `qwen3-coder:30b` alongside the gateway

---

## Setup

### 1. Install Ollama and pull models

Install Ollama from https://ollama.com, then pull both models:

```bash
ollama pull qwen3-coder:30b
ollama pull glm-4.7-flash
```

Verify both are available:

```bash
ollama list
```

### 2. Configure the OpenClaw config file

Copy the example config and fill in your bot tokens and IDs:

```bash
mkdir -p ~/.openclaw
cp finance-bot/openclaw.json.example ~/.openclaw/openclaw.json
```

Open `~/.openclaw/openclaw.json` in your editor and replace:

- `YOUR_DISCORD_BOT_TOKEN` — create a bot at https://discord.com/developers/applications
- `YOUR_GUILD_ID` — right-click your Discord server > Copy Server ID (requires Developer Mode)
- `YOUR_CHANNEL_ID` — right-click the channel > Copy Channel ID

For Telegram, uncomment the `telegram` section and set `YOUR_TELEGRAM_BOT_TOKEN` (from @BotFather) and `YOUR_TELEGRAM_USER_ID`.

### 3. Set up environment secrets

Copy the env example and fill in your gateway token:

```bash
cp finance-bot/.env.example finance-bot/.env
```

Edit `finance-bot/.env`:

```env
# Required
OPENCLAW_GATEWAY_TOKEN=generate-a-long-random-string-here

# Required — primary news/research engine
TAVILY_API_KEY=tvly-your-key-here

# Optional: moomoo trading (paper mode via SIMULATE)
MOOMOO_OPEND_HOST=127.0.0.1
MOOMOO_OPEND_PORT=11111
MOOMOO_TRADE_ENV=SIMULATE

# Optional: cloud model fallback (leave blank to use Ollama only)
ANTHROPIC_API_KEY=

# Optional: override the default watchlist
FINANCE_MONITOR_WATCHLIST=AAPL,MSFT,NVDA,BTC-USD,ETH-USD
```

To generate a secure gateway token:

```bash
openssl rand -hex 32
```

### 4. Create the agent workspaces

```bash
openclaw setup --workspace ~/.openclaw/workspace-finclaw
openclaw setup --workspace ~/.openclaw/workspace-finclaw-coder
openclaw setup --workspace ~/.openclaw/workspace-finclaw-monitor
```

### 5. Copy workspace files

Seed the main agent workspace with the bundled finance agent files:

```bash
cp -r finance-bot/workspace/* ~/.openclaw/workspace-finclaw/
```

### 6. Start FinClaw

**Option A — Docker Compose (recommended for persistent background operation):**

```bash
docker-compose -f finance-bot/docker-compose.finance.yml up -d
```

Check logs:

```bash
docker logs -f finclaw-gateway
```

**Option B — Direct run (for development or quick testing):**

```bash
openclaw gateway run
```

### 7. Say hello

Open your Discord channel (or Telegram chat) and send a message:

```
What is the current price of NVDA?
```

FinClaw will respond via the same channel. You can ask it to build scripts, set price alerts, summarize news, or analyze your portfolio.

---

## Recommended Ollama Context Configuration

By default, Ollama may use a smaller context window than the model supports. For `qwen3-coder:30b`, create a custom Modelfile to lock in a 65K context (a good balance of performance and memory on 32 GB RAM):

```
FROM qwen3-coder:30b

PARAMETER num_ctx 65536
```

Save as `Modelfile.finclaw` and create the custom model:

```bash
ollama create qwen3-coder-finclaw -f Modelfile.finclaw
```

Then update `openclaw.json` to use `ollama/qwen3-coder-finclaw` as the model for the `finclaw` and `coder` agents.

---

## Security Notes

- **Do not expose port 18789 to the internet.** It is bound to `localhost` by default in the compose file. For remote access from your phone or other machines, use [Tailscale](https://tailscale.com) — it is free for personal use and requires no port forwarding.
- **Always start with paper trading.** Set `MOOMOO_TRADE_ENV=SIMULATE` in your `.env` file until you have verified the bot's behavior over several weeks. Only set `MOOMOO_TRADE_ENV=REAL` when you are fully confident.
- **Keep your `.env` file out of version control.** It is listed in `.gitignore` by default. Double-check before committing.
- **Restrict Discord/Telegram access.** The config uses an allowlist — only the guild/channel or Telegram user IDs you specify can interact with the bot. Do not add public channels.
- **Review exec tool output.** The `exec` tool lets the bot run arbitrary code in the sandbox. The sandbox is Docker-isolated, but review what the bot runs, especially for any scripts that touch external APIs or write files.

---

## Research & News Stack

FinClaw uses a layered approach to gather market intelligence:

| Layer | Source | What It Provides |
|-------|--------|-----------------|
| 1 | **Tavily Search** | Breaking news, analyst reports, earnings details (AI-optimized) |
| 2 | **blogwatcher** (RSS) | 13+ financial feeds — Reuters, CNBC, Bloomberg, SEC EDGAR, Fed, CoinDesk |
| 3 | **earnings-tracker** | Earnings calendar, EPS estimates, historical surprise data, price reactions |
| 4 | **yfinance** | Price history, fundamentals, analyst ratings, basic headlines |
| 5 | **Browser** | Full web browsing — TradingView charts, SEC filings, broker dashboards |

The monitor subagent runs blogwatcher on a cron schedule (6am, 12pm, 4:30pm ET) and filters headlines by your watchlist. Tavily is used on-demand for deep research queries.

---

## Costs

| Component | Cost |
|---|---|
| OpenClaw platform | Free (open source) |
| Ollama + local models | Free |
| Host machine electricity | ~$10-25/month (Ubuntu PC, 32 GB RAM, idle/moderate load) |
| moomoo brokerage | Free for paper trading; $0 commission on US stocks |
| Anthropic API (cloud fallback) | Usage-based; $0 if left blank and Ollama is working |
| Tavily Search API | Free tier (1,000 queries/month); paid plans available |
| Discord / Telegram bots | Free |

Running FinClaw fully locally with Ollama costs nothing beyond electricity and hardware depreciation.
