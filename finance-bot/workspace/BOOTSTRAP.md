# Bootstrap — First-Run Ritual

Run this ONCE on a fresh workspace. Delete this file when complete.

---

## Step 1 — Install ClawHub CLI

```bash
npm install -g clawhub
clawhub --version
```

---

## Step 2 — Security Skills (ALWAYS FIRST — never skip)

```bash
clawhub install skill-vetter
clawhub install agentguard
```

Verify with `clawhub list` before proceeding.

---

## Step 3 — Configure Built-in Tools

These require no install — just one-time setup:

```bash
# Agent Browser (HOST MACHINE COMMAND - run on host, not in agent sandbox): controls isolated Chrome/Brave profile)
openclaw browser --browser-profile openclaw start

# GitHub (enables github + gh-issues skills)
gh auth login

# nano-pdf (read SEC filings, research PDFs)
pip install nano-pdf

# jq + ripgrep (enables session-logs skill)
# apt install jq ripgrep   ← Linux
# brew install jq ripgrep  ← Mac
```

Install Python dependencies for all finance skills:
```bash
pip install yfinance pandas ta pytz feedparser moomoo-api
```

Set in your `.env` file:
```
TAVILY_API_KEY=tvly-...      # REQUIRED — get free key at app.tavily.com
BRAVE_SEARCH_API_KEY=...     # fallback search — 2000 free queries/month
NOTION_API_KEY=...           # trade journal (optional)
TRELLO_API_KEY=...           # optional kanban
```

---

## Step 4 — Search & Research Skills

```bash
clawhub install tavily           # best search for AI agents — install first
clawhub install brave-search
clawhub install web-fetch
clawhub install x-research       # optional: needs Twitter/X API key
```

---

## Step 5 — Finance Skills

```bash
clawhub install coingecko
clawhub install portfolio-watcher
clawhub install earnings-tracker
clawhub install actual-budget    # optional: only if you use Actual Budget
```

---

## Step 6 — Automation & Proactive Skills

```bash
clawhub install cron-scheduler
clawhub install webhook-triggers
clawhub install proactive-agent
clawhub install api-gateway
```

---

## Step 7 — Coding, Memory & Self-Improvement Skills

```bash
clawhub install agent-brain
clawhub install agent-team-orchestration
clawhub install find-skills
clawhub install self-improving-agent
clawhub install advanced-skill-creator
clawhub install agentic-security-audit
clawhub install alex-session-wrap-up
clawhub install opencode
```

---

## Step 8 — Prediction Market Skills (moderate risk)

```bash
clawhub install polyclaw
clawhub install kalshi
```

---

## Step 9 — Vet All Installed Skills

```bash
clawhub list
```

Ask FinClaw: "Use skill-vetter to audit every installed ClawHub skill."
Do not proceed if any skill fails vetting.

---

## Step 10 — Configure agent-brain Memory Store

Ask FinClaw: "Initialize agent-brain memory store in the workspace."

---

## Step 11 — Run Normal Boot

Execute the `BOOT.md` checklist.

---

## Step 12 — Delete This File

```bash
rm BOOTSTRAP.md
```

Bootstrap complete. FinClaw is ready.

---

## Crypto Trading Skills (deferred — install only when ready)

Do NOT install during bootstrap. Add only after weeks of successful paper trading:

```bash
# clawhub install bankr/token-trading
# clawhub install bankr/leverage-trading
# clawhub install bankr/automation
```

---

> SECURITY: The ClawHavoc incident (Feb 2026) found 341 malicious ClawHub skills.
> Vet every installed skill. Never skip Step 2.
