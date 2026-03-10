# Autonomous Trading Strategy

## Overview
Run this strategy autonomously every market scan. Research → Decide → Execute → Reinvest.
All profits are reinvested immediately to compound returns.

---

## Market Trend Override (Master Gate — Runs BEFORE Everything Else)

The market trend check is the outermost gate of the entire strategy. It runs before the halal filter, before news, before RSI — before any individual stock analysis whatsoever. A great stock setup in a collapsing market is still a losing trade. This gate prevents the bot from fighting the tape.

Run the market-trend skill at the start of every session:
```bash
python3 market_trend.py --json
```

Read the `verdict` and `position_size_multiplier` fields. Apply the rules below immediately and for the entire session.

### STRONG_BEAR (score 0–2)
- **No new buy positions. Period.**
- Cash is the position. Even score-10 individual setups get skipped.
- Only action: tighten stops on existing holdings (consider moving stop to -5% from entry instead of -7%).
- Do NOT average down on any existing position.
- Discord alert: "MARKET VERDICT: STRONG_BEAR — Bot holding cash. No new positions until conditions improve."
- `allow_new_buys = False` — exit the scan after managing existing stops.

### BEAR (score 2–4)
- **Max 3 open positions simultaneously** (do not open a 4th even if capital is available).
- **Position size = 40% of normal** (`position_size_multiplier = 0.40`).
- **Minimum buy score raised to 5.0** (normal minimum is 3.0). Marginal setups are skipped entirely.
- Only consider the absolute highest-conviction halal trades (ideally defensive-sector names).
- Tighten stop losses on existing positions: consider -5% instead of -7%.
- Momentum boost does NOT apply in BEAR conditions — no relaxing thresholds.

### NEUTRAL (score 4–6)
- **Position size = 70% of normal** (`position_size_multiplier = 0.70`).
- **Minimum buy score raised to 3.5** (not 3.0). Skip anything on the fence.
- Do not open more than 5 simultaneous positions.
- Skip any trade where the only buy signals are momentum signals. Core signals (RSI, news, MA) must be present.
- Normal stop loss (-7%) applies.

### BULL (score 6–8)
- **Normal rules apply.** `position_size_multiplier = 1.00`.
- **Minimum buy score: 3.0** (standard threshold).
- Normal position count limits apply.
- All scan steps proceed as documented below.

### STRONG_BULL (score 8–10)
- **Position size up to 120% of normal** (`position_size_multiplier = 1.20`) on highest conviction trades.
- **Minimum buy score relaxed to 2.5** — the broad market is supporting moves, so good setups that just miss the normal threshold are worth taking.
- Scan entire watchlist aggressively. Do not pre-filter by sector.
- Momentum score boost still applies and can contribute to reaching the 2.5 threshold.
- Normal stop loss (-7%) still applies — STRONG_BULL does not change risk management.

### Position Size Stacking With Economic Calendar

The market trend multiplier stacks multiplicatively with the economic calendar multiplier (from ECONOMIC_CALENDAR_RULES.md):

```
final_position_size = normal_size × market_trend_multiplier × economic_calendar_multiplier
```

Examples:
- NEUTRAL market (0.70) × CPI day CAUTION (0.50) = **0.35× normal size**
- BEAR market (0.40) × CLEAR calendar (1.00) = **0.40× normal size**
- BULL market (1.00) × FOMC AVOID → **no new buys** (AVOID overrides everything)
- STRONG_BULL (1.20) × NFP CAUTION (0.50) = **0.60× normal size**

The economic calendar AVOID verdict always wins — if the calendar says AVOID or GO_TO_CASH, that blocks new buys regardless of market trend verdict.

---

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

## Momentum Signals (supplementary — applied ONLY after halal check passes and 2+ core signals are already met)

Momentum adds a small score boost. It never initiates a trade on its own.

**Momentum Buy Signals** — each qualifying signal adds +0.5 to buy score (cap: +1 total from momentum):
- **Price momentum**: Stock up >3% in last 5 days AND above 20-day MA (short-term trend confirmation)
- **Relative strength**: Stock outperforming SPY by >5% over last 20 days (sector strength)
- **Volume momentum**: Volume 1.5x above 20-day average for 3+ consecutive days (institutional accumulation)
- **52-week high proximity**: Within 10% of 52-week high with strong volume (breakout setup)

**Momentum Sell Signals** — any ONE triggers a sell:
- Price drops >5% in a single day on high volume (momentum reversal)
- Stock underperforms SPY by >10% over 10 days (losing momentum)

**Momentum Position Sizing**: trades where momentum boosted the score get SMALLER position sizes — max 1% portfolio risk (half the normal 2%). Momentum moves fast and has higher false positive rates.

**Hard rule**: momentum scoring only runs after halal check passes AND at least 2 core signals (RSI, news) are already confirmed. Never trade on momentum alone.

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
