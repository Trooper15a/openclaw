---
name: app-builder
description: "Builds web apps, scripts, dashboards, and tools using Claude Code as a coding subagent. Use when: user asks to build an app, create a trading dashboard, write a script, automate a task. NOT for: quick one-liner fixes (just use exec directly), reading/analyzing code (read files directly)."
metadata:
  {
    "openclaw":
      {
        "emoji": "🏗️",
        "requires": { "bins": ["claude"] },
      },
  }
---

# App Builder

## When to Use

- User asks to build a stock or crypto dashboard (web UI or terminal)
- User wants to create a backtesting script for a trading strategy
- User asks to write a data pipeline (fetch prices, clean data, store, report)
- User wants to build a portfolio web app with charts and tables
- User asks to automate a recurring task (e.g., daily report emailer, price alert bot)
- Any multi-file coding task that would benefit from an autonomous coding agent

Do NOT use this skill for:
- Quick one-liner fixes or single-function edits — just write the code directly
- Reading or analyzing existing code — read the files directly and reason about them

## How It Works

This skill spawns Claude Code as a coding subagent using the `claude` CLI. Claude Code operates in `bypassPermissions` mode, which means it can read, write, and execute files autonomously without prompting for each action. It handles:

- Creating full directory and file structures
- Writing multi-file applications across frameworks
- Installing dependencies and running build steps
- Iterating on the code to fix errors before returning

The subagent runs to completion and returns its full output, which this bot then reviews to confirm what was built.

## Usage Pattern

```bash
cd /path/to/project && claude --permission-mode bypassPermissions --print 'Your detailed task description'
```

For tasks that take a long time (e.g., large apps, slow installs), use `background: true` so the bot is not blocked. Check back on the output after it completes.

Keep the working directory (`cd` target) as specific as possible — point it at the project folder, not the workspace root, to keep generated files organized.

## Project Templates

Use these as starting points when the user asks to build something new.

### Finance Dashboard (Next.js + Tailwind)

Purpose: Real-time price display, portfolio chart, news feed.

Suggested prompt:
> Build a Next.js 14 app in `./dashboard` using Tailwind CSS and the App Router. Features: (1) price ticker bar showing BTC, ETH, SPY, AAPL refreshed every 30s via yfinance API route, (2) portfolio summary card reading from `../portfolio.json`, (3) news feed with last 5 headlines from Yahoo Finance. No auth required. Use shadcn/ui components.

### Backtesting Script (Python + pandas + matplotlib)

Purpose: Load historical OHLCV data, apply a strategy, calculate returns, plot results.

Suggested prompt:
> Write a Python backtesting script at `./backtest/run.py`. It should: load 2 years of daily OHLCV data for a given ticker using yfinance, implement a simple moving average crossover strategy (50d/200d), calculate total return, Sharpe ratio, and max drawdown, then plot equity curve vs buy-and-hold using matplotlib. Accept ticker and date range as CLI args.

### Alert Bot (Node.js)

Purpose: Webhook receiver or polling loop that evaluates price conditions and sends notifications.

Suggested prompt:
> Build a Node.js alert bot in `./alert-bot`. It should: poll yfinance every 60 seconds for a configurable list of tickers, evaluate threshold conditions defined in `alerts.json` (e.g., price above/below value, % change in 24h), and send a Discord webhook notification when a condition triggers. Use `node-fetch` and `dotenv`. Include a sample `alerts.json`.

### Data Pipeline (Python)

Purpose: Fetch price/fundamental data, clean it, store to SQLite or CSV, generate a report.

Suggested prompt:
> Build a Python data pipeline in `./pipeline`. Steps: (1) fetch daily OHLCV for a ticker list from yfinance, (2) clean and normalize the data (handle missing values, align dates), (3) store to a local SQLite database, (4) generate a CSV summary report with 30-day return, volatility, and 52-week high/low for each ticker. Schedule-ready: should run cleanly as a cron job.

## Good Prompt Structure

A well-structured prompt for Claude Code includes all of the following:

```
Build a [type of app/script] in [target directory].

It should:
- [Feature 1]
- [Feature 2]
- [Feature 3]

Use [tech stack / language / framework].

Include [specific requirements, e.g., error handling, CLI args, config file format].

Test with [test data, sample ticker, or example input].
```

Example:

> Build a portfolio CSV exporter script in `./tools/export.py`. It should: read `portfolio.json`, fetch current prices via yfinance, calculate P&L for each position, and write a CSV file with columns: ticker, shares, avg_cost, current_price, market_value, unrealized_pnl, pnl_pct. Use Python with pandas. Accept an optional `--output` CLI flag for the output path. Test with the existing portfolio.json in the workspace.

The more specific the prompt, the better the output. Vague prompts produce generic code; specific prompts produce working code on the first attempt.

## Output Handling

After Claude Code finishes, always:

1. Read the generated files to verify they exist and are non-empty.
2. Check for a `package.json`, `requirements.txt`, or equivalent to confirm dependencies are declared.
3. Report back to the user with:
   - What was built (one-sentence summary)
   - File structure (list the key files and their purpose)
   - How to run it (exact command, e.g., `cd dashboard && npm run dev` or `python3 backtest/run.py AAPL`)
   - Any manual steps required (e.g., set an env variable, install system dependencies)

If key files are missing or appear empty, re-invoke Claude Code with a follow-up prompt asking it to complete the missing parts before reporting success to the user.
