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

### Step 3b — Momentum Score (run only if core score >= 2 AND halal check passed)
After calculating the core score (RSI, news, volume, MA), layer in momentum signals:
- Check each of the 4 momentum signals defined in MOMENTUM_RULES.md
- Add +0.5 for each momentum signal present (max +1 total added to score from momentum)
- If any momentum signal triggered, flag the candidate as `momentum_boosted = true`
- Log which momentum signals fired, e.g.: "Momentum: +0.5 price momentum (up 4.1% in 5d, above 20MA), +0.5 volume momentum (1.8x avg for 4 days) — total momentum boost: +1"
- If `momentum_boosted = true`, cap position size at 1% portfolio risk instead of the normal 2%

## Step 4 — Earnings Check (REQUIRED before any buy)
For the full candidates list from Step 3, run the earnings-tracker skill:
- Call `scan_upcoming_earnings(candidates, days_ahead=2)` to find any ticker reporting within 48h
- Remove those tickers from the buy list — do NOT buy them regardless of score
- Log each skipped ticker with reason: "SKIPPED [TICKER] — earnings within 48h ([date])"
- If a held position has earnings within 24h AND unrealized gain > 5%, sell/reduce that position now (log reason: "Pre-earnings profit lock — earnings [date]")

## Step 5 — Execute Best Opportunities
Sort remaining candidates by score (highest first).
For each top candidate (up to available capital at 10% per trade):
- Place limit buy order via moomoo-trader skill
- Log to paper-trading/trades.md with full reasoning
- Update portfolio.json
- Send Discord message: "Bought X shares of [TICKER] at $Y — Reason: [reasoning]"

## Step 6 — Reinvest Profits
If any sells happened this scan and profit was made:
- Calculate profit amount
- Find best scoring candidate from Step 3
- Reinvest profit immediately if good opportunity exists (earnings check still applies)
- Log reinvestment to trades.md

## Step 7 — Report
Send Discord summary:
- Trades made this scan (buys + sells)
- Current portfolio value
- Best and worst performers
- Next scan time
