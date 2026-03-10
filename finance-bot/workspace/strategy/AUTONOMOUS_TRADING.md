# Autonomous Trading — Agent Instructions

When triggered by cron or user, run this full loop:

---

## Step 0 — Market Trend Prediction (Run FIRST — Before Everything Else)

This is the outermost gate. It runs before mode check, before economic calendar, before any stock analysis. The market trend verdict sets the rules for the entire session.

### What to Run

```bash
python3 market_trend.py --json
```

Or call the market-trend skill directly if orchestrated via the agent team.

### What to Read From the Output

Parse the JSON output and extract these session-wide variables:

```python
market_verdict           = result["verdict"]               # STRONG_BULL / BULL / NEUTRAL / BEAR / STRONG_BEAR
market_score             = result["score"]                 # 0.0 to 10.0
position_size_multiplier = result["position_size_multiplier"]  # 0.0 / 0.40 / 0.70 / 1.00 / 1.20
min_buy_score            = result["min_buy_score"]         # 2.5 / 3.0 / 3.5 / 5.0 / None
allow_new_buys           = result["allow_new_buys"]        # False if STRONG_BEAR
max_positions            = result.get("max_positions", 10) # BEAR = 3, NEUTRAL = 5, others = 10
```

These variables are passed into every subsequent step. All steps that involve buying use `position_size_multiplier` and `min_buy_score` from this step.

### Routing Logic

```
IF market_verdict == "STRONG_BEAR":
    → Send Discord alert: "MARKET VERDICT: STRONG_BEAR (score X.X/10). No new buys. Cash only."
    → Proceed to Step 1 (mode check) and Step 2 (existing positions — manage stops only).
    → Skip Step 3 (scan for new opportunities) — set allow_new_buys = False.
    → Skip Step 4 (earnings check — no buy candidates exist).
    → Skip Step 5 (execute buys — none allowed).
    → Skip Step 6 (reinvest — no buys to fund).
    → Go to Step 7 (report) — include STRONG_BEAR verdict prominently.

ELSE:
    → Continue to Step 1 as normal.
    → Carry market_verdict, position_size_multiplier, min_buy_score into all downstream steps.
```

### If market_trend.py Fails

If the script errors out or returns malformed JSON:
- Default `market_verdict = "NEUTRAL"`
- Default `position_size_multiplier = 0.70`
- Default `min_buy_score = 3.5`
- Default `allow_new_buys = True`
- Log: "MARKET TREND CHECK FAILED — defaulting to NEUTRAL. Proceeding with reduced position sizes."
- Send Discord warning.

Never default to BULL on a failure. Always default conservative.

### Discord Message for Step 0

Include in every morning brief:

```
MARKET TREND: BULL (7.2/10)
  Macro:     8.0/10 — SPY above 200MA (+2.1%), VIX=18 (calm), Golden cross active
  Breadth:   7.0/10 — 64% stocks above 200MA, A/D ratio=1.8
  Sectors:   7.0/10 — Tech +6.8% vs Utilities -1.2% (20d), Risk-on: 3/4 sectors leading
  Sentiment: 6.0/10 — Fear&Greed=58 (neutral-greed), Put/Call=0.82

  Session rules: Normal position sizes (1.00x). Min score to buy: 3.0.
```

---

## Step 1 — Check Mode
Read USER.md. If mode is PAPER, use moomoo SIMULATE.
If mode is LIVE, warn in Discord before any trade.

## Step 2 — Check Existing Positions
Read portfolio.json and portfolio/positions.md.
For each held position:
- Get current price via yfinance
- Check stop loss (-7%) and take profit (+15%)
  - In BEAR or STRONG_BEAR market: tighten stop mentally to -5% (log as "tightened stop — BEAR market conditions")
- Search Tavily for breaking news on each ticker
- SELL immediately if stop loss hit OR major negative news
- SELL HALF if take profit hit, let rest run
- This step always runs regardless of market_verdict (stops must be managed even in STRONG_BEAR).

## Step 3 — Scan for New Opportunities
**Only runs if `allow_new_buys == True` (i.e., market_verdict is not STRONG_BEAR).**

For each ticker in watchlist.json:
- Run halal check (AUTO_STRATEGY.md) — skip if fails
- Get RSI + 20MA + volume via yfinance python script
- Search Tavily: "[TICKER] stock news today"
- Score 0-5, record reasoning
- Add to candidates list if score >= `min_buy_score` (set by Step 0, not a fixed 3)
  - STRONG_BULL: score >= 2.5
  - BULL: score >= 3.0 (default)
  - NEUTRAL: score >= 3.5
  - BEAR: score >= 5.0

In BEAR market: additionally filter candidates to only include defensive/non-cyclical sectors where possible.
In NEUTRAL market: skip any candidate where the only signals are momentum-based — require at least one core signal (RSI, MA, news).

### Step 3b — Momentum Score (run only if core score >= 2 AND halal check passed)
After calculating the core score (RSI, news, volume, MA), layer in momentum signals:
- Check each of the 4 momentum signals defined in MOMENTUM_RULES.md
- Add +0.5 for each momentum signal present (max +1 total added to score from momentum)
- If any momentum signal triggered, flag the candidate as `momentum_boosted = true`
- Log which momentum signals fired, e.g.: "Momentum: +0.5 price momentum (up 4.1% in 5d, above 20MA), +0.5 volume momentum (1.8x avg for 4 days) — total momentum boost: +1"
- If `momentum_boosted = true`, cap position size at 1% portfolio risk instead of the normal 2%
- **In BEAR market: momentum boost does NOT apply. Do not add +0.5 for momentum signals.**

## Step 4 — Earnings Check (REQUIRED before any buy)
**Only runs if `allow_new_buys == True`.**

For the full candidates list from Step 3, run the earnings-tracker skill:
- Call `scan_upcoming_earnings(candidates, days_ahead=2)` to find any ticker reporting within 48h
- Remove those tickers from the buy list — do NOT buy them regardless of score
- Log each skipped ticker with reason: "SKIPPED [TICKER] — earnings within 48h ([date])"
- If a held position has earnings within 24h AND unrealized gain > 5%, sell/reduce that position now (log reason: "Pre-earnings profit lock — earnings [date]")

## Step 5 — Execute Best Opportunities
**Only runs if `allow_new_buys == True`.**

Sort remaining candidates by score (highest first).
For each top candidate (up to available capital at 10% per trade):
- **Apply position sizing**: `trade_size = normal_trade_size × position_size_multiplier × economic_calendar_multiplier`
  - `position_size_multiplier` comes from Step 0 (market trend)
  - `economic_calendar_multiplier` comes from the economic calendar check (run between Step 1 and Step 3)
- **Respect max positions limit**:
  - BEAR: max 3 total open positions (skip buy if already at 3)
  - NEUTRAL: max 5 total open positions
  - BULL / STRONG_BULL: standard limits from AUTO_STRATEGY.md
- Place limit buy order via moomoo-trader skill
- Log to paper-trading/trades.md with full reasoning including market_verdict
- Update portfolio.json
- Send Discord message: "Bought X shares of [TICKER] at $Y — Market: [verdict]. Reason: [reasoning]"

## Step 6 — Reinvest Profits
**Only runs if `allow_new_buys == True` and profits were realized this session.**

If any sells happened this scan and profit was made:
- Calculate profit amount
- Find best scoring candidate from Step 3 (must still be in the qualified list after Step 4)
- Reinvest profit immediately if good opportunity exists (earnings check still applies)
- Apply the same `position_size_multiplier` to reinvestment sizing
- Log reinvestment to trades.md

## Step 7 — Report
Send Discord summary:
- **Market Trend verdict and score** (always first line)
- Trades made this scan (buys + sells)
- Current portfolio value
- Best and worst performers
- If STRONG_BEAR: "No new positions taken. Holding cash. Stops active on existing positions."
- If BEAR: "Restricted buying mode. Max 3 positions. Position sizes at 40%."
- Next scan time
