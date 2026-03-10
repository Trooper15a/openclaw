---
name: economic-calendar
description: "Checks upcoming high-impact economic events (Fed meetings, CPI, NFP, GDP) that could cause major market volatility. Use when: running pre-market scan to decide if today is safe to trade, checking if it's safe to open new positions. NOT for: price monitoring, stock analysis."
metadata:
  {
    "openclaw": {
      "emoji": "📅",
      "requires": { "bins": ["python3"], "pip": ["requests", "pandas"] }
    }
  }
---

# Economic Calendar

## When to Use

- First thing in every pre-market scan — before RSI, before news, before any buy decision
- User asks "is it safe to trade today?" or "what's on the calendar this week?"
- Checking whether to hold cash or reduce position sizes
- Any time the bot is about to open a new position — verify no major event is within 24h

## When NOT to Use

- Real-time price alerts — use `finance-monitor`
- Stock-specific news — use `tavily` or `x-research`
- Earnings dates — use `earnings-tracker`

## Setup

```bash
pip install requests pandas
```

No API key required. Uses Forex Factory's free public weekly calendar JSON endpoint.

## Trading Rules (Hard Rules — Non-Negotiable)

| Scenario | Rule |
|---|---|
| FOMC day or day before FOMC | NO new BUY positions. Do not add to existing positions. |
| CPI day | Reduce all new position sizes by 50%. No new buys in the final 2h before release. |
| NFP (Non-Farm Payrolls) day | Reduce all new position sizes by 50%. No new buys before 8:30 AM ET. |
| PCE release day | No new BUY positions. Hold existing positions unless stop-loss triggered. |
| GDP release day | Reduce new position sizes by 50%. Extra scrutiny on any buy. |
| 3 or more HIGH impact events in one week | Go to CASH — sell all open positions before the first event. Re-enter after the week clears. |
| Any HIGH impact event within 24h | Do not open new positions. Monitor existing positions closely. |
| MEDIUM impact event today | Reduce position size by 25%. Proceed with caution. |
| No events today or tomorrow | Normal trading rules apply. |

## Impact Levels

### HIGH Impact (AVOID trading)
- **FOMC** — Federal Reserve interest rate decision and statement
- **CPI** — Consumer Price Index (inflation)
- **PCE** — Personal Consumption Expenditures (Fed's preferred inflation gauge)
- **NFP** — Non-Farm Payrolls (monthly jobs report)
- **GDP** — Gross Domestic Product (quarterly)
- **FOMC Minutes** — Fed meeting minutes release
- **Fed Chair Speech** — Powell or successor press conference / congressional testimony

### MEDIUM Impact (CAUTION — reduce size)
- **PPI** — Producer Price Index
- **Retail Sales** — Monthly retail sales report
- **Consumer Confidence** — Conference Board or UoM Consumer Sentiment
- **ISM Manufacturing** — Institute for Supply Management Manufacturing PMI
- **ISM Services** — ISM Non-Manufacturing PMI
- **ADP Employment** — Private payrolls (precursor to NFP)
- **Jobless Claims** — Weekly unemployment claims (if unusually high/low)

### LOW Impact (TRADE normally)
- Housing starts, building permits, durable goods (unless a major miss)
- Most regional Fed surveys

## Data Source

**Forex Factory Weekly Calendar (free, no API key)**

Endpoint: `https://nfs.faireconomy.media/ff_calendar_thisweek.json`

Returns all economic events for the current week. Filtered to USD events with HIGH or MEDIUM impact only.

**Fallback**: If Forex Factory is unreachable, check `https://finance.yahoo.com/calendar/economic` or fall back to a hardcoded FOMC calendar (dates are published a year in advance).

## Python Script

```python
#!/usr/bin/env python3
"""
economic_calendar.py — Fetch and filter high-impact USD economic events.
Source: Forex Factory free weekly calendar JSON (no API key required).
"""

import requests
import json
from datetime import datetime, timedelta, timezone
import sys

CALENDAR_URL = "https://nfs.faireconomy.media/ff_calendar_thisweek.json"

# Keywords that map to HIGH impact events
HIGH_IMPACT_KEYWORDS = [
    "Non-Farm",
    "NFP",
    "Nonfarm",
    "CPI",
    "Consumer Price Index",
    "PCE",
    "Personal Consumption",
    "FOMC",
    "Fed Rate",
    "Federal Funds Rate",
    "Interest Rate Decision",
    "GDP",
    "Gross Domestic Product",
    "Fed Chair",
    "Powell",
    "FOMC Minutes",
    "Federal Open Market",
]

# Keywords that map to MEDIUM impact events
MEDIUM_IMPACT_KEYWORDS = [
    "PPI",
    "Producer Price",
    "Retail Sales",
    "Consumer Confidence",
    "Consumer Sentiment",
    "ISM Manufacturing",
    "ISM Non-Manufacturing",
    "ISM Services",
    "ADP Employment",
    "ADP Nonfarm",
    "Jobless Claims",
    "Unemployment Claims",
]

# Recommendation mapping
RECOMMENDATIONS = {
    "HIGH": "AVOID",
    "MEDIUM": "CAUTION",
    "LOW": "TRADE",
}


def classify_event(title: str, ff_impact: str) -> str:
    """Override Forex Factory's impact level with our own keyword-based classification."""
    title_upper = title.upper()

    for kw in HIGH_IMPACT_KEYWORDS:
        if kw.upper() in title_upper:
            return "HIGH"

    for kw in MEDIUM_IMPACT_KEYWORDS:
        if kw.upper() in title_upper:
            return "MEDIUM"

    # Fall back to Forex Factory's own impact label
    if ff_impact and ff_impact.upper() == "HIGH":
        return "HIGH"
    if ff_impact and ff_impact.upper() == "MEDIUM":
        return "MEDIUM"

    return "LOW"


def fetch_calendar() -> list:
    """Fetch this week's calendar from Forex Factory. Returns raw event list."""
    try:
        resp = requests.get(CALENDAR_URL, timeout=10, headers={"User-Agent": "Mozilla/5.0"})
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        print(f"[economic-calendar] WARNING: Could not fetch from Forex Factory: {e}")
        return []


def parse_events(raw: list) -> list:
    """Filter to USD events, classify impact, attach recommendation."""
    events = []
    for item in raw:
        # Only care about USD events
        if item.get("country", "").upper() != "USD":
            continue

        title = item.get("title", "Unknown Event")
        ff_impact = item.get("impact", "")
        impact = classify_event(title, ff_impact)

        # Skip LOW impact events — not relevant to trading rules
        if impact == "LOW":
            continue

        # Parse date string — Forex Factory uses ISO 8601
        date_str = item.get("date", "")
        try:
            # Format: "2026-03-10T08:30:00-05:00" (ET)
            dt = datetime.fromisoformat(date_str)
        except Exception:
            try:
                # Sometimes provided without timezone
                dt = datetime.strptime(date_str[:16], "%Y-%m-%dT%H:%M")
                dt = dt.replace(tzinfo=timezone.utc)
            except Exception:
                continue

        events.append({
            "date": dt.date().isoformat(),
            "time_et": dt.strftime("%I:%M %p ET") if dt.hour != 0 else "All Day",
            "datetime": dt,
            "title": title,
            "impact": impact,
            "forecast": item.get("forecast", "N/A"),
            "previous": item.get("previous", "N/A"),
            "recommendation": RECOMMENDATIONS[impact],
        })

    return sorted(events, key=lambda x: x["datetime"])


def get_window_label(event_date_str: str, today: datetime.date, tomorrow: datetime.date) -> str:
    from datetime import date as date_type
    d = datetime.fromisoformat(event_date_str).date() if "T" not in event_date_str else date_type.fromisoformat(event_date_str)
    if d == today:
        return "TODAY"
    elif d == tomorrow:
        return "TOMORROW"
    else:
        return d.strftime("%A %b %d")


def check_cash_rule(events: list, today) -> bool:
    """Return True if 3+ HIGH impact events exist in the coming 7 days."""
    cutoff = today + timedelta(days=7)
    high_count = sum(
        1 for e in events
        if e["impact"] == "HIGH" and today <= datetime.fromisoformat(e["date"]).date() <= cutoff
    )
    return high_count >= 3


def print_report(events: list):
    from datetime import date as date_type
    today = date_type.today()
    tomorrow = today + timedelta(days=1)
    seven_days = today + timedelta(days=7)

    print("=" * 60)
    print("  ECONOMIC CALENDAR — MARKET RISK REPORT")
    print(f"  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')} ET")
    print("=" * 60)

    # --- Cash rule check ---
    if check_cash_rule(events, today):
        print()
        print("  !! GO TO CASH WARNING !!")
        print("  3 or more HIGH IMPACT events detected this week.")
        print("  Rule: SELL ALL POSITIONS before the first event.")
        print("  Re-evaluate after the week clears.")
        print()

    # Filter events to next 7 days
    upcoming = [
        e for e in events
        if today <= datetime.fromisoformat(e["date"]).date() <= seven_days
    ]

    if not upcoming:
        print()
        print("  No HIGH or MEDIUM impact USD events in the next 7 days.")
        print("  STATUS: CLEAR — Normal trading rules apply.")
        print()
        return

    # Group by window
    for window_label in ["TODAY", "TOMORROW"] + [
        (today + timedelta(days=i)).strftime("%A %b %d") for i in range(2, 8)
    ]:
        window_events = []
        for e in upcoming:
            ed = datetime.fromisoformat(e["date"]).date()
            if window_label == "TODAY" and ed == today:
                window_events.append(e)
            elif window_label == "TOMORROW" and ed == tomorrow:
                window_events.append(e)
            elif window_label not in ("TODAY", "TOMORROW"):
                target = datetime.strptime(window_label, "%A %b %d").replace(year=today.year).date()
                if ed == target:
                    window_events.append(e)

        if not window_events:
            continue

        print()
        print(f"  --- {window_label} ---")
        for e in window_events:
            rec_symbol = {"AVOID": "X", "CAUTION": "!", "TRADE": "OK"}[e["recommendation"]]
            print(f"  [{rec_symbol}] {e['time_et']:>12}  |  {e['impact']:<6}  |  {e['title']}")
            print(f"       Forecast: {e['forecast']}   Previous: {e['previous']}")
            print(f"       Action: {e['recommendation']} — ", end="")
            if e["recommendation"] == "AVOID":
                print("No new positions. No adds. Watch existing stops.")
            elif e["recommendation"] == "CAUTION":
                print("Reduce new position sizes by 25-50%. Trade with extra care.")
            else:
                print("Normal rules apply.")
            print()

    print("=" * 60)

    # --- Summary verdict ---
    today_events = [e for e in upcoming if datetime.fromisoformat(e["date"]).date() == today]
    tomorrow_events = [e for e in upcoming if datetime.fromisoformat(e["date"]).date() == tomorrow]

    has_today_high = any(e["impact"] == "HIGH" for e in today_events)
    has_tomorrow_high = any(e["impact"] == "HIGH" for e in tomorrow_events)
    has_today_medium = any(e["impact"] == "MEDIUM" for e in today_events)

    print()
    print("  TRADING VERDICT:")
    if has_today_high or has_tomorrow_high:
        print("  STATUS: AVOID — High impact event today or tomorrow.")
        print("  Do NOT open new positions. Hold cash. Monitor stops.")
    elif has_today_medium:
        print("  STATUS: CAUTION — Medium impact event today.")
        print("  Reduce position sizes by 25-50%. Proceed carefully.")
    else:
        print("  STATUS: CLEAR — No major events today or tomorrow.")
        print("  Normal trading rules apply.")
    print()


def get_calendar_json() -> dict:
    """Return structured JSON for programmatic use by the trading bot."""
    from datetime import date as date_type
    today = date_type.today()
    tomorrow = today + timedelta(days=1)
    seven_days = today + timedelta(days=7)

    raw = fetch_calendar()
    events = parse_events(raw)

    upcoming = [
        e for e in events
        if today <= datetime.fromisoformat(e["date"]).date() <= seven_days
    ]

    today_events = [e for e in upcoming if datetime.fromisoformat(e["date"]).date() == today]
    tomorrow_events = [e for e in upcoming if datetime.fromisoformat(e["date"]).date() == tomorrow]
    week_events = upcoming  # already filtered to 7 days

    go_to_cash = check_cash_rule(events, today)
    has_high_today = any(e["impact"] == "HIGH" for e in today_events)
    has_high_tomorrow = any(e["impact"] == "HIGH" for e in tomorrow_events)
    has_medium_today = any(e["impact"] == "MEDIUM" for e in today_events)

    if go_to_cash:
        overall_verdict = "GO_TO_CASH"
    elif has_high_today or has_high_tomorrow:
        overall_verdict = "AVOID"
    elif has_medium_today:
        overall_verdict = "CAUTION"
    else:
        overall_verdict = "CLEAR"

    # Remove non-serializable datetime objects
    def clean(ev_list):
        return [{k: v for k, v in e.items() if k != "datetime"} for e in ev_list]

    return {
        "generated_at": datetime.now().isoformat(),
        "overall_verdict": overall_verdict,
        "go_to_cash": go_to_cash,
        "today": clean(today_events),
        "tomorrow": clean(tomorrow_events),
        "next_7_days": clean(week_events),
    }


if __name__ == "__main__":
    if "--json" in sys.argv:
        raw = fetch_calendar()
        events = parse_events(raw)
        result = get_calendar_json()
        print(json.dumps(result, indent=2))
    else:
        raw = fetch_calendar()
        events = parse_events(raw)
        print_report(events)
```

## Usage

### Human-readable report (default)
```bash
python3 economic_calendar.py
```

### JSON output (for bot integration)
```bash
python3 economic_calendar.py --json
```

### Programmatic use inside the trading bot
```python
import sys
sys.path.insert(0, "/path/to/skills/economic-calendar")
from economic_calendar import get_calendar_json

cal = get_calendar_json()

if cal["overall_verdict"] == "GO_TO_CASH":
    # Sell everything, log reason, stop scan
    raise SystemExit("CALENDAR: GO_TO_CASH — 3+ high impact events this week")

if cal["overall_verdict"] == "AVOID":
    # No new positions today or tomorrow
    allow_new_buys = False

elif cal["overall_verdict"] == "CAUTION":
    # Reduce position sizes
    position_size_multiplier = 0.50  # 50% of normal

else:
    # CLEAR — normal rules apply
    allow_new_buys = True
    position_size_multiplier = 1.0
```

## Output Format

### Human-readable example

```
============================================================
  ECONOMIC CALENDAR — MARKET RISK REPORT
  Generated: 2026-03-10 08:00 ET
============================================================

  --- TODAY ---
  [X]     08:30 AM ET  |  HIGH    |  CPI m/m
       Forecast: 0.3%   Previous: 0.4%
       Action: AVOID — No new positions. No adds. Watch existing stops.

  --- TOMORROW ---
  [OK]    08:30 AM ET  |  MEDIUM  |  PPI m/m
       Forecast: 0.2%   Previous: 0.3%
       Action: CAUTION — Reduce new position sizes by 25-50%. Trade with extra care.

  --- Thursday Mar 12 ---
  [X]     08:30 AM ET  |  HIGH    |  Non-Farm Payrolls
       Forecast: 185K   Previous: 177K
       Action: AVOID — No new positions. No adds. Watch existing stops.

============================================================

  TRADING VERDICT:
  STATUS: AVOID — High impact event today or tomorrow.
  Do NOT open new positions. Hold cash. Monitor stops.
```

### JSON output example

```json
{
  "generated_at": "2026-03-10T08:00:00",
  "overall_verdict": "AVOID",
  "go_to_cash": false,
  "today": [
    {
      "date": "2026-03-10",
      "time_et": "08:30 AM ET",
      "title": "CPI m/m",
      "impact": "HIGH",
      "forecast": "0.3%",
      "previous": "0.4%",
      "recommendation": "AVOID"
    }
  ],
  "tomorrow": [
    {
      "date": "2026-03-11",
      "time_et": "08:30 AM ET",
      "title": "PPI m/m",
      "impact": "MEDIUM",
      "forecast": "0.2%",
      "previous": "0.3%",
      "recommendation": "CAUTION"
    }
  ],
  "next_7_days": [ ... ]
}
```

## Integration with Other Skills

- **proactive-agent / cron-scheduler**: Run this skill FIRST in every pre-market scan. If verdict is AVOID or GO_TO_CASH, skip the rest of the scan.
- **earnings-tracker**: Both checks run at Step 4 of AUTONOMOUS_TRADING.md. Economic calendar is checked first (macro risk), then earnings-tracker (ticker-specific risk).
- **moomoo-trader**: Before placing any order, re-check `overall_verdict`. If not CLEAR, block the order.
- **finance-monitor**: On HIGH impact event days, tighten alert thresholds — flag moves of ±1% instead of the usual ±3%.
- **portfolio-tracker**: Include today's calendar verdict in the daily portfolio summary Discord message.

## Currency — Canadian Dollars (CAD)

Economic events are USD-denominated macro events. When summarizing their likely market impact in chat, convert any dollar figures (e.g., retail sales dollar amounts) to CAD using the current `CADUSD=X` rate from yfinance.

## Ethical Screening (Halal Filter)

This skill does not involve individual stocks. No halal filtering applies. Economic calendar data is purely macroeconomic and applies to all positions equally.

## Failure Handling

If the Forex Factory endpoint is unreachable:
1. Log a warning: `[economic-calendar] WARNING: Calendar unavailable — defaulting to CAUTION for today`
2. Return verdict: `"CAUTION"` (never default to CLEAR on a fetch failure)
3. The bot should proceed with reduced position sizes (50%) until the calendar can be verified
4. Retry on next scheduled scan
