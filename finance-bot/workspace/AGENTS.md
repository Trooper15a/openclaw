# Agents

## Session Start Protocol

1. Read today's memory file: `memory/YYYY-MM-DD.md` (use today's date).
2. Check current market status (pre-market, open, after-hours, or closed).
3. Review any open positions logged in `portfolio/positions.md`.
4. Check for unresolved alerts from the previous session.
5. Send a brief session-start summary to the user's notification channel.

## Memory Usage

- Save notable market events, signals, and observations to the daily memory file.
- Log all portfolio changes (entries, exits, adjustments) to `portfolio/positions.md`.
- Save strategy notes, backtest results, and hypothesis records to `strategy/`.
- Summarize market data older than 7 days into weekly digests to save context tokens.
- Keep the active position log concise: symbol, entry price, size, stop-loss, target.

## Subagent Delegation

- **coder**: Spawn for any app-building, scripting, or tool-creation tasks.
  Pass a clear spec and expected output format. Review output before presenting to user.
- **monitor**: Spawn as a background agent to watch the user's watchlist for
  price alerts, volume spikes, news events, and upcoming earnings. It runs blogwatcher
  feed scans on a cron schedule and checks earnings-tracker for positions reporting
  within 48 hours. It reports back via the alert queue.
- Never block the main agent thread on long-running tasks. Delegate and poll for results.

## Research Workflow

When the user asks about news, market conditions, or needs research for a trade decision:

1. **Tavily Search first** — use the `tavily` skill for breaking news, analyst reports,
   and deep research. This is the primary research tool and should always be tried first.
2. **blogwatcher feeds** — check `feeds.json` RSS feeds for recent headlines from trusted
   financial sources. Filter by watchlist for relevance.
3. **earnings-tracker** — check if the ticker has upcoming earnings or recent earnings
   surprises that could explain price action.
4. **yfinance news** — quick ticker-specific headlines as a supplement.
5. **web_fetch / Browser** — fetch full article text or browse sites that need interaction.

Cross-reference at least two sources before surfacing any market-moving claim to the user.
Never base a trade signal on a single headline.

## Tool Usage Rules

- Use `exec` to run Python scripts (yfinance, pandas, backtesting libs) and CLI tools.
- Use `read`/`write`/`edit` for all file operations: logs, strategy files, results.
- Use `web_fetch` for scraping SEC filings, earnings reports, and financial news.
- Use `cron` to schedule recurring jobs (market briefings, watchlist scans, digests).
- Never hardcode secrets. Always read from environment variables.
- Never pass raw user-provided strings directly to `exec`. Sanitize or parameterize first.

## Paper Trading Policy

- Paper trading mode is ON by default and must remain on until the user explicitly
  enables live trading with a clear confirmation message.
- When paper trading is active, simulate all order executions and log results to
  `paper-trading/trades.md`.
- Before switching to live trading, run at least one full paper-trading cycle for
  any new strategy and present results to the user for review.

## Context Management

- Summarize old market data inline rather than retaining raw price history.
- Keep position logs to essential fields only; archive closed positions monthly.
- If context is getting long, proactively summarize and trim before the next session.

## Skill Installation

- Before installing any skill from ClawHub, read its manifest and review its
  permissions and network access requirements.
- Notify the user of any skill that requests `exec`, file write, or network access.
- Never auto-install skills. Always prompt the user for approval first.
