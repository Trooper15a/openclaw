---
name: earnings-tracker
description: "Tracks upcoming earnings dates, EPS estimates, historical earnings surprises, and post-earnings price moves. Use when: (1) user asks 'when does NVDA report earnings', (2) checking if any held positions have earnings this week, (3) reviewing a stock's earnings beat/miss history, (4) pre-earnings analysis before a trade. NOT for: real-time price monitoring (use finance-monitor), full technical/fundamental scoring (use stock-analysis)."
metadata:
  {
    "openclaw":
      {
        "emoji": "📅",
        "requires": { "bins": ["python3"] },
      },
  }
---

# Earnings Tracker

## When to Use

- User asks when a company reports earnings
- Checking if any watchlist or portfolio stocks have earnings coming up this week
- Reviewing historical EPS surprise data (beats vs misses)
- Pre-earnings trade setup — understanding expectations before the event
- Morning briefings that include upcoming earnings catalysts

## When NOT to Use

- Real-time price alerts — use `finance-monitor`
- Full 8-dimension stock analysis — use `stock-analysis`
- Executing trades around earnings — this skill is informational only

## Setup

```bash
pip install yfinance pandas pytz
```

No API key required. All data comes from Yahoo Finance via yfinance.

## Key Commands

### Get next earnings date for a ticker

```python
import yfinance as yf

def get_earnings_date(symbol: str) -> str:
    ticker = yf.Ticker(symbol)
    try:
        cal = ticker.calendar
        if cal is not None and not cal.empty:
            # calendar is a DataFrame — earnings date is typically in the first column
            earnings_date = cal.iloc[0, 0] if hasattr(cal, 'iloc') else str(cal)
            return str(earnings_date)
    except Exception:
        pass

    # Fallback: check earnings_dates property
    try:
        dates = ticker.earnings_dates
        if dates is not None and not dates.empty:
            # Future dates first
            import pandas as pd
            from datetime import datetime
            future = dates[dates.index >= pd.Timestamp(datetime.now())]
            if not future.empty:
                return str(future.index[0].date())
            return str(dates.index[0].date())
    except Exception:
        pass

    return "Not available"

print(f"NVDA next earnings: {get_earnings_date('NVDA')}")
```

### Get earnings history with surprise data

```python
import yfinance as yf
import pandas as pd

def get_earnings_history(symbol: str, quarters: int = 8) -> pd.DataFrame:
    """Returns last N quarters of earnings with actual vs estimate and surprise %."""
    ticker = yf.Ticker(symbol)
    try:
        dates = ticker.earnings_dates
        if dates is None or dates.empty:
            return pd.DataFrame()

        # Filter to rows that have actual EPS (i.e., past earnings)
        past = dates[dates["Reported EPS"].notna()].head(quarters)

        results = []
        for idx, row in past.iterrows():
            actual = row.get("Reported EPS")
            estimate = row.get("EPS Estimate")
            surprise_pct = row.get("Surprise(%)")

            if actual is not None and estimate is not None and estimate != 0:
                beat = "BEAT" if actual > estimate else "MISS" if actual < estimate else "MET"
            else:
                beat = "N/A"

            results.append({
                "date": idx.strftime("%Y-%m-%d"),
                "actual_eps": actual,
                "estimate_eps": estimate,
                "surprise_pct": surprise_pct,
                "result": beat,
            })

        return pd.DataFrame(results)
    except Exception as e:
        print(f"Error fetching earnings history for {symbol}: {e}")
        return pd.DataFrame()

df = get_earnings_history("AAPL")
print(df.to_string(index=False))
```

### Scan watchlist for upcoming earnings this week

```python
import yfinance as yf
import os
from datetime import datetime, timedelta
import pytz

def scan_upcoming_earnings(tickers: list, days_ahead: int = 7) -> list:
    """Returns tickers with earnings in the next N days."""
    et = pytz.timezone("America/New_York")
    now = datetime.now(et)
    cutoff = now + timedelta(days=days_ahead)
    upcoming = []

    for symbol in tickers:
        try:
            ticker = yf.Ticker(symbol)
            dates = ticker.earnings_dates
            if dates is None or dates.empty:
                continue

            import pandas as pd
            future = dates[dates.index >= pd.Timestamp(now)]
            if future.empty:
                continue

            next_date = future.index[0]
            if next_date <= pd.Timestamp(cutoff):
                estimate = future.iloc[0].get("EPS Estimate")
                upcoming.append({
                    "ticker": symbol,
                    "date": next_date.strftime("%Y-%m-%d"),
                    "eps_estimate": estimate,
                })
        except Exception:
            continue

    return sorted(upcoming, key=lambda x: x["date"])

watchlist = os.environ.get("FINANCE_MONITOR_WATCHLIST", "AAPL,MSFT,NVDA").split(",")
upcoming = scan_upcoming_earnings(watchlist)
for item in upcoming:
    est = f"EPS est: ${item['eps_estimate']:.2f}" if item['eps_estimate'] else "EPS est: N/A"
    print(f"  {item['ticker']} reports {item['date']} — {est}")
if not upcoming:
    print("  No earnings in the next 7 days for watchlist tickers.")
```

### Post-earnings price reaction history

```python
import yfinance as yf
import pandas as pd

def earnings_price_reactions(symbol: str, quarters: int = 4) -> list:
    """Shows how the stock moved the day after each earnings report."""
    ticker = yf.Ticker(symbol)
    hist = ticker.history(period="2y", auto_adjust=True)

    try:
        dates = ticker.earnings_dates
        past = dates[dates["Reported EPS"].notna()].head(quarters)
    except Exception:
        return []

    reactions = []
    for idx, row in past.iterrows():
        earnings_date = idx.date()
        # Find the next trading day after earnings
        post_earnings = hist[hist.index.date > earnings_date]
        pre_earnings = hist[hist.index.date <= earnings_date]

        if post_earnings.empty or pre_earnings.empty:
            continue

        close_before = float(pre_earnings["Close"].iloc[-1])
        close_after = float(post_earnings["Close"].iloc[0])
        move_pct = ((close_after - close_before) / close_before) * 100

        reactions.append({
            "date": str(earnings_date),
            "result": "BEAT" if row.get("Reported EPS", 0) > row.get("EPS Estimate", 0) else "MISS",
            "close_before": close_before,
            "close_after": close_after,
            "move_pct": move_pct,
        })

    return reactions

for r in earnings_price_reactions("AAPL"):
    direction = "UP" if r["move_pct"] > 0 else "DOWN"
    print(f"  {r['date']}: {r['result']} -> {direction} {abs(r['move_pct']):.1f}%  (${r['close_before']:.2f} -> ${r['close_after']:.2f})")
```

## Output Format

### Upcoming Earnings Alert

```
EARNINGS ALERT — Week of 2026-03-09

Upcoming reports for watchlist holdings:
  NVDA  — Wed Mar 11 (after close) — EPS est: $0.92
  AAPL  — Thu Mar 12 (after close) — EPS est: $1.58

Earnings history (last 4 quarters):
  NVDA: 4/4 BEATS — avg surprise +12.3% — stock avg +4.2% next day
  AAPL: 3/4 BEATS — avg surprise +5.1% — stock avg +1.8% next day

Action items:
  - Review position sizing before earnings
  - Consider hedging or trimming if position is >15% of portfolio
  - Set post-earnings price alerts
```

### Single Ticker Earnings Profile

```
EARNINGS PROFILE — NVDA (NVIDIA Corporation)

Next report    : 2026-03-11 (after close)
EPS estimate   : $0.92
Revenue est    : $38.2B

Last 8 Quarters:
  Date        Actual  Estimate  Surprise   Stock Move
  2025-11-20  $0.81   $0.75     +8.0%      +3.2% (BEAT)
  2025-08-28  $0.68   $0.64     +6.3%      +5.1% (BEAT)
  2025-05-28  $0.61   $0.58     +5.2%      -1.4% (BEAT, sell-the-news)
  2025-02-26  $0.52   $0.49     +6.1%      +8.9% (BEAT)
  ...

Track record: 8/8 BEATS — avg surprise +6.4%
Avg post-earnings move: +3.8% (range: -1.4% to +8.9%)
```

## Integration with Other Skills

- **stock-analysis**: Include earnings surprise score in Dimension 4
- **finance-monitor**: Trigger an alert 48 hours before any held position reports earnings
- **portfolio-tracker**: Flag positions with upcoming earnings in daily portfolio summary
- **proactive-agent**: Automatically surface "NVDA reports in 2 days" without user asking

## Currency — Canadian Dollars (CAD)

All EPS estimates, price reactions, and monetary values MUST be displayed in **Canadian dollars (C$)**.
Convert USD figures to CAD using the `CADUSD=X` forex rate from Yahoo Finance.
TSX-listed tickers (`.TO` suffix) are already in CAD.

## Ethical Screening (Halal Filter)

Do NOT track or report earnings for excluded sectors: alcohol, arms/defense, drugs (recreational), gambling, tobacco/smoking, vice.
If an excluded ticker appears in a watchlist scan, silently skip it.
