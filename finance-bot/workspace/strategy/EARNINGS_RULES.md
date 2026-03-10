# Earnings Rules

These rules are enforced on every scan cycle. Violations are not permitted — earnings volatility
is unpredictable and overrides all other buy/sell signals.

## Rule 1 — Never Buy Within 48 Hours of Earnings

Before placing any buy order, check the earnings date of the candidate ticker using the
earnings-tracker skill. If earnings are within 48 hours (2 calendar days), DO NOT BUY.
This applies regardless of score, momentum, or news sentiment.

- Use `scan_upcoming_earnings(tickers, days_ahead=2)` from the earnings-tracker skill.
- Remove any flagged ticker from the buy list for this scan cycle.
- Log: `SKIPPED [TICKER] — earnings within 48h ([YYYY-MM-DD]). Will re-evaluate post-earnings.`

## Rule 2 — Reduce Position Before Earnings if in Profit

For each held position, check if earnings are within 24 hours. If earnings are within 24h AND
the unrealized gain is greater than 5%, reduce the position by 50% to lock in profit.

- Sell half the position via a limit order at current bid.
- Log: `Pre-earnings trim — [TICKER] earnings [date], gain [X]%, sold 50% of position.`
- Keep the remaining 50% to benefit from a potential positive surprise.
- If unrealized gain is 5% or less, hold the full position (not enough profit to justify trimming).

## Rule 3 — Post-Earnings Re-Entry Cooldown

After a stock reports earnings, wait 1 full trading day before re-entering a position.
This allows the market to digest the report and price action to stabilize.

- Day 0: earnings reported (after close or pre-market) — do not trade.
- Day 1 (next full trading session): re-evaluate using normal buy signals.
- If score >= 3 and no other blockers, the ticker is eligible to buy again.

## Watchlist — Tickers to Check Every Scan

Run earnings check on all of the following every cycle:

US:
- AAPL, MSFT, NVDA, GOOGL, AMZN, TSLA, META, SPY, QQQ

Canada (TSX):
- SHOP.TO, RY.TO, TD.TO, ENB.TO

Note: SPY and QQQ are ETFs and do not report earnings — the earnings-tracker skill will return
no date for them. They are safe to buy at any time from an earnings-risk standpoint.

Note: RY.TO and TD.TO are excluded by the Halal filter and should never reach the earnings check.
They are listed here for completeness in case the watchlist is used by other tools.
