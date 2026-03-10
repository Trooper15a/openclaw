# Autonomous Trading — Agent Instructions

When triggered by cron or user, run this full loop:

## Step 1 — Check Mode
Read USER.md. If mode is PAPER, use moomoo SIMULATE.
If mode is LIVE, warn in Discord before any trade.

## Step 2 — Check Existing Positions
Read portfolio.json and portfolio/positions.md.
For each held position:
- Get current price via yfinance
- Check stop loss (-7%) and take profit (+15%)
- Search Tavily for breaking news on each ticker
- SELL immediately if stop loss hit OR major negative news
- SELL HALF if take profit hit, let rest run

## Step 3 — Scan for New Opportunities
For each ticker in watchlist.json:
- Run halal check (AUTO_STRATEGY.md) — skip if fails
- Get RSI + 20MA + volume via yfinance python script
- Search Tavily: "[TICKER] stock news today"
- Score 0-5, record reasoning
- Add to candidates list if score >= 3

## Step 4 — Execute Best Opportunities
Sort candidates by score (highest first).
For each top candidate (up to available capital at 10% per trade):
- Place limit buy order via moomoo-trader skill
- Log to paper-trading/trades.md with full reasoning
- Update portfolio.json
- Send Discord message: "Bought X shares of [TICKER] at $Y — Reason: [reasoning]"

## Step 5 — Reinvest Profits
If any sells happened this scan and profit was made:
- Calculate profit amount
- Find best scoring candidate from Step 3
- Reinvest profit immediately if good opportunity exists
- Log reinvestment to trades.md

## Step 6 — Report
Send Discord summary:
- Trades made this scan (buys + sells)
- Current portfolio value
- Best and worst performers
- Next scan time
