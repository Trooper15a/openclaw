# Autonomous Trading Strategy

## Overview
Run this strategy autonomously every market scan. Research → Decide → Execute → Reinvest.
All profits are reinvested immediately to compound returns.

## Halal Filter (Non-Negotiable — check FIRST before any research)
NEVER buy any stock that:
- Is a bank or conventional financial institution (interest-based: RY, TD, BMO, BNS, CM, JPM, BAC, etc.)
- Earns primary revenue from alcohol (breweries, distilleries, bars)
- Earns primary revenue from tobacco or cannabis
- Earns primary revenue from gambling or casinos
- Is a conventional insurance company (interest-based)
- Is involved in weapons manufacturing as primary business
- Is involved in pork production or processing
- Earns significant revenue (>5%) from haram activities

ALLOWED (generally permissible):
- Tech companies (AAPL, MSFT, NVDA, GOOGL, AMZN, META)
- Healthcare and pharma
- Energy (oil, gas, renewables)
- Real estate (non-REIT or Shariah-compliant REIT)
- Retail and consumer goods
- Crypto (BTC, ETH — treat as speculative asset, small allocation only)

If unsure about a company — skip it. Never buy a doubtful stock.

## Capital Rules
- Starting paper balance: $10,000 CAD
- Max per trade: 10% of current portfolio value
- Max single position: 15% of portfolio
- Stop loss: -7% from entry (sell immediately, no exceptions)
- Take profit: +15% from entry (sell half, let rest run)
- Always keep minimum 20% cash reserve

## Buy Signals (need 3+ to trigger a buy)
1. **Halal check** — passes halal filter above (required, not optional)
2. **Earnings check PASS** — no earnings within 48h (NON-NEGOTIABLE — if earnings are within 48h, skip the trade regardless of all other signals; use earnings-tracker skill to verify)
3. **News sentiment** — Tavily search shows positive news in last 24h, no red flags
4. **Technical** — RSI < 45 (not overbought), price above 20-day MA
5. **Volume** — above average volume (momentum confirmation)

## Sell Signals (any ONE triggers a sell)
1. Stop loss hit: price down 7% from entry
2. Take profit hit: price up 15% (sell half, let rest run)
3. Major negative news breaks on a held position
4. Company fails halal filter on re-check (divest immediately)
5. Earnings within 24h AND unrealized gain > 5% — sell/reduce position to lock in profit before earnings risk

## Research Process (run for each candidate)
1. Halal check first — skip immediately if fails
2. `tavily search` — "[TICKER] stock news today" + "[TICKER] analyst rating"
3. `yfinance` — get RSI, 20-day MA, volume vs average
4. Score 0-5 based on buy signals
5. Only buy if score >= 3

## Reinvestment Rule (Compounding Loop)
After every profitable sell:
- Calculate profit
- Scan watchlist for best halal opportunity with score >= 3
- Reinvest full profit immediately
- If no good opportunity found, hold cash until next scan

## Execution
- Use moomoo-trader skill for all orders
- LIMIT orders only — never market orders
- Log every trade AND reasoning to `paper-trading/trades.md`
- Update `portfolio.json` after every trade
- Send Discord notification for every buy/sell with reasoning

## Scan Schedule
- Pre-market: 8:30am ET — news scan, no trades
- Market hours: every 2 hours (9:30am, 11:30am, 1:30pm, 3:30pm ET)
- After-hours: 5:00pm ET — review day, update portfolio, plan tomorrow
