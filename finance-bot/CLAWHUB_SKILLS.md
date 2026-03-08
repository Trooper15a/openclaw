# FinClaw — Skills Reference

Two types of skills:
- **Built-in** — core OpenClaw tools, always available, no install
- **Bundled** — ship with OpenClaw, available immediately, no install needed
- **ClawHub** — external, install via `clawhub install <name>`, always vet first

---

## Built-in Tools (always available, no install)

These are core OpenClaw capabilities — not skills, but always accessible via tool calls.

| Tool | What it does | Finance use case |
|------|--------------|-----------------|
| **Browser** | Controls a dedicated isolated Chrome/Brave/Edge profile — open tabs, click, type, screenshot, scrape | Browse SEC EDGAR filings, TradingView charts, broker dashboards, any site that needs login |
| **Exec** | Run shell commands, Python scripts, CLI tools | Run yfinance scripts, curl APIs, run backtesting |
| **Cron** | Schedule recurring tasks natively | Daily market briefings, hourly price scans |
| **Read/Write/Edit** | File system access | Manage portfolio.json, strategy files, memory logs |
| **Web Fetch** | Fetch and parse URLs | Pull financial data from any URL |
| **Sessions/Spawn** | Spawn and communicate with subagents | Delegate to coder or monitor subagent |
| **Message** | Send messages to your channels | Alert you on Discord/Telegram |

### Browser — Finance Use Cases

The built-in browser is powerful for finance work that requires real browsing:

```
"Open TradingView and take a screenshot of the AAPL daily chart"
"Log into my moomoo paper trading account and check my open positions"
"Browse SEC EDGAR and download the latest NVDA 10-K filing"
"Scrape the options chain for TSLA from Yahoo Finance"
"Open CoinMarketCap and get the top 10 coins by volume right now"
```

Enable the browser profile once:
```bash
openclaw browser --browser-profile openclaw start
```

---

## Bundled Skills (no install — ready to use)

These ship with OpenClaw. Configure where an API key is needed.

### Code & Version Control

| Skill | What it does | Setup |
|-------|--------------|-------|
| `github` | GitHub ops via `gh` CLI — push apps, open PRs, manage issues, check CI runs | `gh auth login` |
| `gh-issues` | Fetch issues, spawn subagents to implement fixes and open PRs automatically | `gh auth login` |
| `coding-agent` | Delegate multi-file coding to Claude Code, Codex, or OpenCode as a subagent | `claude` CLI installed |
| `skill-creator` | Create and package new custom skills from scratch | None |

### Research & Documents

| Skill | What it does | Setup |
|-------|--------------|-------|
| `summarize` | Summarize URLs, podcasts, YouTube videos — earnings calls, analyst interviews | None |
| `nano-pdf` | Read and edit PDFs — SEC filings, annual reports, research papers | `pip install nano-pdf` |
| `session-logs` | Search and analyze past agent conversations with jq | `jq`, `rg` installed |
| `xurl` | Post/search Twitter/X API v2 directly — read market sentiment posts | None (uses X config) |

### Productivity & Notes

| Skill | What it does | Setup |
|-------|--------------|-------|
| `notion` | Create/manage Notion pages and databases — trade journal, research notes | Notion API key |
| `obsidian` | Work with Obsidian markdown vaults — local private strategy notes | `obsidian-cli` |
| `trello` | Manage Trello boards and cards — track positions, strategy backlog | Trello API key |

### Communication & Alerts

| Skill | What it does | Setup |
|-------|--------------|-------|
| `slack` | Send trade alerts and summaries to Slack | Slack channel configured |
| `discord` | Discord channel operations | Discord channel configured |

### Infrastructure & Monitoring

| Skill | What it does | Setup |
|-------|--------------|-------|
| `tmux` | Control persistent terminal sessions — long-running background processes | `tmux` installed |
| `canvas` | Render HTML dashboards and charts in OpenClaw's node UI (Mac/iOS/Android) | OpenClaw node connected |
| `clawhub` | ClawHub CLI — search, install, update, publish skills | `npm i -g clawhub` |
| `model-usage` | Track LLM token usage and cost per model | None |
| `healthcheck` | Security audit and hardening for the machine running OpenClaw | None |
| `blogwatcher` | Monitor RSS/Atom feeds — financial blogs, analyst feeds, SEC RSS | `blogwatcher` CLI |

---

## ClawHub Skills (install via clawhub)

> Always install `skill-vetter` and `agentguard` first. See BOOTSTRAP.md.

### Security (install before everything else)

| Skill | Install | What it does |
|-------|---------|--------------|
| `skill-vetter` | `clawhub install skill-vetter` | Scans skills for malware, prompt injections, suspicious patterns before use |
| `agentguard` | `clawhub install agentguard` | Real-time runtime safety layer — blocks dangerous operations |

---

### Search & Research

| Skill | Install | What it does | API Key? |
|-------|---------|--------------|----------|
| `tavily` | `clawhub install tavily` | Tavily Search API — built specifically for AI agents, returns clean structured results ideal for LLM consumption. Much better signal-to-noise than raw Google for research tasks | Yes (free tier available) |
| `brave-search` | `clawhub install brave-search` | Real-time web search — news, SEC filings, earnings, analyst reports | Yes (free: 2k/mo) |
| `web-fetch` | `clawhub install web-fetch` | Scrape any URL — SEC EDGAR, earnings transcripts, financial sites | No |
| `x-research` | `clawhub install x-research` | Monitor Twitter/X — sentiment, trending tickers, analyst posts | Yes |

**Tavily vs Brave Search:** Use Tavily when you need clean, summarised, agent-friendly results (better for chaining into further reasoning). Use Brave when you need raw search results or news links.

Tavily setup:
```
TAVILY_API_KEY=tvly-...   # get free key at: https://app.tavily.com
```

---

### Finance — Market Data

| Skill | Install | What it does | API Key? |
|-------|---------|--------------|----------|
| `coingecko` | `clawhub install coingecko` | Real-time prices for 10,000+ crypto tokens, market cap, 24h change | No |
| `portfolio-watcher` | `clawhub install portfolio-watcher` | Monitor holdings, price alerts, real-time P&L — no brokerage needed | No |
| `earnings-tracker` | `clawhub install earnings-tracker` | Earnings calendar, EPS estimates, historical surprise data | No |
| `actual-budget` | `clawhub install actual-budget` | Query personal finances via self-hosted Actual Budget | Self-hosted |

---

### Finance — Trading & Prediction Markets

> Start with paper trading. Run for 4–8 weeks before enabling live execution.

| Skill | Install | What it does | Risk |
|-------|---------|--------------|------|
| `polyclaw` | `clawhub install polyclaw` | Trade on Polymarket prediction markets | Medium |
| `kalshi` | `clawhub install kalshi` | Kalshi markets — prices, orderbook, positions and P&L | Medium |

**Crypto Trading (BankrBot — high risk, install last):**
```bash
clawhub install bankr/token-trading      # buy/sell tokens on-chain (EVM chains)
clawhub install bankr/leverage-trading   # leveraged positions via Hyperliquid
clawhub install bankr/automation         # rules-based auto-trading strategies
```
> Use a dedicated wallet with a small test amount. Never connect your main wallet.

---

### Automation

| Skill | Install | What it does |
|-------|---------|--------------|
| `cron-scheduler` | `clawhub install cron-scheduler` | Richer UI for scheduling recurring tasks — briefings, scans, rebalances |
| `webhook-triggers` | `clawhub install webhook-triggers` | Trigger actions on price events or inbound webhooks |
| `proactive-agent` | `clawhub install proactive-agent` | Enables the agent to take initiative — surface insights, send unprompted alerts, suggest trades based on market conditions without you asking first |
| `api-gateway` | `clawhub install api-gateway` | Unified gateway for managing multiple external APIs — handles auth rotation, rate limiting, retry logic, and routing across finance data providers from a single interface |

**proactive-agent use cases for FinClaw:**
- "Alert me when any watchlist stock moves more than 3% in a session"
- "Send me a morning briefing every day at 9am without me asking"
- "Suggest rebalancing when a position drifts more than 5% from target"
- "Warn me if an earnings date is within 48 hours for any held position"

---

### Coding & Orchestration

| Skill | Install | What it does |
|-------|---------|--------------|
| `opencode` | `clawhub install opencode` | OpenCode AI coding agent — alternative to Claude Code for building apps |
| `agent-team-orchestration` | `clawhub install agent-team-orchestration` | Multi-agent teams with defined roles, task lifecycles, and handoff protocols |
| `self-improving-agent` | `clawhub install self-improving-agent` | Enables FinClaw to analyse its own past decisions, identify failure patterns, and autonomously update its own AGENTS.md rules and skills to improve over time |
| `find-skills` | `clawhub install find-skills` | Searches ClawHub for skills relevant to a task description — FinClaw can discover and propose new skills to install on its own |
| `advanced-skill-creator` | `clawhub install advanced-skill-creator` | FinClaw autonomously writes and installs brand-new custom skills |
| `agent-brain` | `clawhub install agent-brain` | Persistent SQLite memory — agents remember facts, preferences, and decisions across sessions |
| `agentic-security-audit` | `clawhub install agentic-security-audit` | Audits generated code and infrastructure for security vulnerabilities |
| `alex-session-wrap-up` | `clawhub install alex-session-wrap-up` | Commits unpushed work, extracts learnings, persists rules after each coding session |

**self-improving-agent + find-skills together** make FinClaw genuinely self-evolving:
- `find-skills` lets it discover what tools exist for a task
- `self-improving-agent` lets it install them and update its own behaviour rules
- Combined with `advanced-skill-creator`, it can write entirely new skills when nothing on ClawHub fits

---

## Full Recommended Install Order

```bash
# ── STEP 1: Security (never skip) ──────────────────────────────
clawhub install skill-vetter
clawhub install agentguard

# ── STEP 2: Search & Research ───────────────────────────────────
clawhub install tavily               # best search for AI agents
clawhub install brave-search
clawhub install web-fetch
clawhub install x-research

# ── STEP 3: Finance core ────────────────────────────────────────
clawhub install coingecko
clawhub install portfolio-watcher
clawhub install earnings-tracker

# ── STEP 4: Automation & Proactive ──────────────────────────────
clawhub install cron-scheduler
clawhub install webhook-triggers
clawhub install proactive-agent
clawhub install api-gateway

# ── STEP 5: Coding, Memory & Self-Improvement ───────────────────
clawhub install agent-brain
clawhub install agent-team-orchestration
clawhub install find-skills
clawhub install self-improving-agent
clawhub install advanced-skill-creator
clawhub install agentic-security-audit
clawhub install alex-session-wrap-up
clawhub install opencode

# ── STEP 6: Prediction markets (moderate risk) ──────────────────
clawhub install polyclaw
clawhub install kalshi

# ── STEP 7: Vet everything installed ────────────────────────────
# Ask FinClaw: "Use skill-vetter to audit every installed skill"

# ── STEP 8: Crypto trading — only when ready ────────────────────
# clawhub install bankr/token-trading
# clawhub install bankr/leverage-trading
# clawhub install bankr/automation

# ── Bundled skills to configure (no install, just auth) ─────────
# gh auth login                          → enables github + gh-issues
# pip install nano-pdf                   → enables nano-pdf (SEC filings)
# Set NOTION_API_KEY in .env             → enables notion (trade journal)
# Set TAVILY_API_KEY in .env             → enables tavily search
# Set BRAVE_SEARCH_API_KEY in .env       → enables brave-search
# openclaw browser --browser-profile openclaw start  → enables agent browser
```

---

## Security Notes

- The **ClawHavoc incident** (Feb 2026) found 341 malicious ClawHub skills — especially in the finance category
- Always check a skill's VirusTotal report on its ClawHub page before installing
- `agentguard` is a runtime safety net, not a substitute for pre-install vetting
- Prefer bundled skills over ClawHub equivalents when both exist — bundled are audited by the OpenClaw team
- **Verify all skill names on clawhub.com** before running install — use `clawhub search <term>` to find exact slugs
