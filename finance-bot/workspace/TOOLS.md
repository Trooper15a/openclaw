# Tools

## exec

Use `exec` to run scripts and CLI commands. Always prefer Python scripts with
well-defined inputs and outputs over ad-hoc shell one-liners.

- **yfinance**: Fetch historical prices, fundamentals, options chains, and earnings.
  ```python
  import yfinance as yf
  ticker = yf.Ticker("AAPL")
  hist = ticker.history(period="3mo")
  ```
- **feedparser**: Parse RSS/Atom feeds from financial news sources. See `blogwatcher` skill.
  ```python
  import feedparser
  d = feedparser.parse("https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=100003114")
  ```
- **curl / free APIs**: Use curl or `requests` to hit free endpoints:
  - Yahoo Finance: price quotes, news, earnings
  - CoinGecko: crypto prices, market cap, volume (`https://api.coingecko.com/api/v3/`)
  - FRED (Federal Reserve): macro data (`https://fred.stlouisfed.org/graph/fredgraph.csv`)
  - Alternative.me: Fear & Greed Index (`https://api.alternative.me/fng/?limit=1`)
  - SEC EDGAR: company filings (RSS/Atom feeds)
- **Tavily Search** (REQUIRED — `TAVILY_API_KEY`): AI-native web search for breaking news,
  earnings analysis, analyst reports, and deep research. Use via the `tavily` ClawHub skill.
  This is the primary research engine — always prefer Tavily for news discovery over
  raw `web_fetch` scraping.
- **Backtesting**: Run backtest scripts with `backtesting.py` or `vectorbt`.
  Save results to `strategy/backtest-YYYY-MM-DD.md`.
- Security: Never pass raw user input as a shell argument. Parameterize all inputs.

## read / write / edit

Use for all persistent file operations:

- `portfolio/positions.md` — active and closed positions log
- `paper-trading/trades.md` — paper trade history and P&L
- `strategy/` — strategy specs, backtest results, hypothesis notes
- `memory/YYYY-MM-DD.md` — daily session memory files
- `alerts/queue.md` — pending alerts for the user

Never write API keys, passwords, or secrets to any file.

## web_fetch

Use `web_fetch` for scraping structured web content:

- SEC EDGAR filings: `https://www.sec.gov/cgi-bin/browse-edgar`
- Earnings transcripts and press releases
- Financial news aggregators
- Company investor relations pages

Parse HTML responses with BeautifulSoup when needed. Cache fetched pages to
avoid redundant requests within the same session.

## cron

Schedule recurring jobs using `cron`:

- **9:30am ET (market open)**: Run watchlist scan, send morning briefing.
- **4:00pm ET (market close)**: Run EOD summary, update positions log, send digest.
- **Custom**: User can request additional cron jobs (e.g., hourly crypto scan).

Log cron job results to `logs/cron.log`. Alert the user if any scheduled job fails.

## Coding Subagent

For app-building and code-generation tasks, delegate to a coding subagent:

```bash
claude --permission-mode bypassPermissions --print "YOUR_SPEC_HERE"
```

Always pass a precise, self-contained spec. Review generated code before executing
or presenting it to the user. Never run untrusted generated code without inspection.

## Skill-Based Tools

These workspace skills provide structured patterns for common tasks:

- **earnings-tracker**: Upcoming earnings dates, EPS surprise history, post-earnings
  price reactions. Use before any trade decision near earnings season.
- **blogwatcher**: RSS feed monitoring across 13+ financial sources (Reuters, CNBC,
  Bloomberg, SEC EDGAR, CoinDesk, Fed releases). Powers the morning/EOD news briefings.
- **finance-monitor**: Real-time price alerts and watchlist scanning.
- **stock-analysis**: 8-dimension scoring with BUY/HOLD/SELL signal.
- **market-sentiment**: Fear & Greed, crypto sentiment, headline synthesis.
- **portfolio-tracker**: Position P&L, benchmark comparison, risk metrics.
- **moomoo-trader**: Place, modify, and cancel orders through moomoo OpenAPI.
  Requires OpenD gateway running on the host. Always confirms orders with user first.

## Research Priority Order

When the user asks about news or needs research:

1. **Tavily Search** — first choice for breaking news, analyst reports, earnings details
2. **blogwatcher feeds** — check RSS feeds for recent headlines from trusted sources
3. **yfinance news** — quick ticker-specific headlines (limited depth)
4. **web_fetch** — scrape a specific URL for full article text or SEC filings
5. **Browser** — last resort for sites that require interaction or login

Always cross-reference multiple sources. Never base a trade signal on a single headline.

## API Key Conventions

All API keys and secrets must be set as environment variables, never hardcoded.

| Secret | Env var name | Required? |
|---|---|---|
| Tavily Search | `TAVILY_API_KEY` | **Yes** |
| Discord bot token | `DISCORD_BOT_TOKEN` | Yes (if using Discord) |
| Telegram bot token | `TELEGRAM_BOT_TOKEN` | Yes (if using Telegram) |
| moomoo OpenD host | `MOOMOO_OPEND_HOST` | For trading |
| moomoo trade env | `MOOMOO_TRADE_ENV` | SIMULATE or REAL |
| Brave Search | `BRAVE_SEARCH_API_KEY` | Optional fallback |

Read them in scripts via `os.environ["VAR_NAME"]`. Fail loudly if a required
variable is missing rather than proceeding with undefined behavior.
