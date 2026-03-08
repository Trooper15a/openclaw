---
name: finance-monitor
description: "Monitors stock and crypto prices in real time, tracks watchlists, and sends price alerts. Use when: (1) setting up price alerts for a ticker crossing a threshold, (2) monitoring an active watchlist of positions, (3) running a background price watcher on a heartbeat, (4) doing pre/post market scans for gap moves. NOT for: executing trades (this skill only reads prices), deep fundamental or technical analysis (use stock-analysis)."
metadata:
  {
    "openclaw":
      {
        "emoji": "📊",
        "requires": { "bins": ["python3"] },
      },
  }
---

# Finance Monitor

## When to Use

- Setting up price alerts when a stock or crypto crosses an above/below threshold
- Monitoring a watchlist of tickers and reporting current prices on demand
- Running a background watcher on a recurring heartbeat (e.g. every 5 minutes during market hours)
- Pre-market and post-market scans to identify overnight gap moves
- Checking the last traded price of any ticker supported by Yahoo Finance (equities, ETFs, crypto, forex, futures)
- Tracking multiple positions simultaneously without switching tools

## When NOT to Use

- Executing buy or sell trades — this skill is read-only and has no brokerage integration
- Generating in-depth technical or fundamental analysis reports — use the `stock-analysis` skill for RSI, MACD, earnings data, and scoring

## Setup

Install the Python dependencies once:

```bash
pip install yfinance pytz
```

> Requires Python 3.8+. `pytz` handles timezone conversion on all Python versions.

Optionally set the `FINANCE_MONITOR_WATCHLIST` environment variable with a comma-separated list of tickers:

```bash
export FINANCE_MONITOR_WATCHLIST="AAPL,MSFT,BTC-USD,ETH-USD"
```

## Usage Patterns

### Check the current price of a single ticker

```python
import yfinance as yf

def get_price(ticker: str) -> float:
    t = yf.Ticker(ticker)
    # fast_info.last_price is None outside market hours — fall back to history
    price = t.fast_info.last_price
    if price is None:
        hist = t.history(period="2d", auto_adjust=True)
        price = float(hist["Close"].dropna().iloc[-1])
    return price

print(f"AAPL: C${get_price('AAPL'):.2f}")  # Display in CAD
```

### Get the latest prices for multiple tickers at once

```python
import yfinance as yf

def get_prices(tickers: list) -> dict:
    """
    Returns {ticker: price} for each ticker.
    Handles the yfinance MultiIndex difference between single and multi-ticker downloads.
    """
    if not tickers:
        return {}

    data = yf.download(tickers, period="2d", interval="1d", auto_adjust=True, progress=False)

    # yfinance returns a flat DataFrame for 1 ticker, MultiIndex for 2+
    if len(tickers) == 1:
        price = float(data["Close"].dropna().iloc[-1])
        return {tickers[0]: price}

    close = data["Close"].dropna()
    return {t: float(close[t].iloc[-1]) for t in tickers if t in close.columns}

prices = get_prices(["SHOP.TO", "RY.TO", "TD.TO", "BTC-USD"])
for ticker, price in prices.items():
    print(f"{ticker}: C${price:.2f}")
```

### Heartbeat alert check

Load `watchlist.json`, fetch current prices, fire any triggered alerts:

```python
import json
import yfinance as yf

def check_alerts(watchlist_path: str = "watchlist.json"):
    with open(watchlist_path) as f:
        config = json.load(f)

    tickers = config.get("tickers", [])
    if not tickers:
        return

    prices = get_prices(tickers)  # use helper above
    triggered = []

    for alert in config.get("alerts", []):
        ticker = alert["ticker"]
        price = prices.get(ticker)
        if price is None:
            continue
        if "above" in alert and price >= alert["above"]:
            triggered.append(
                f"PRICE ALERT — {ticker}\n"
                f"Current price : ${price:.2f}\n"
                f"Alert threshold: above ${alert['above']:.2f}\n"
                f"Triggered at  : {get_et_timestamp()}"
            )
        if "below" in alert and price <= alert["below"]:
            triggered.append(
                f"PRICE ALERT — {ticker}\n"
                f"Current price : ${price:.2f}\n"
                f"Alert threshold: below ${alert['below']:.2f}\n"
                f"Triggered at  : {get_et_timestamp()}"
            )

    for msg in triggered:
        print(msg)

check_alerts()
```

### Market hours check

```python
from datetime import datetime, time
import pytz  # pip install pytz — works on Python 3.8+

def market_status() -> str:
    """Returns: OPEN | PRE-MARKET | AFTER-HOURS | CLOSED"""
    et = pytz.timezone("America/New_York")
    now = datetime.now(et)

    if now.weekday() >= 5:  # Saturday=5, Sunday=6
        return "CLOSED"

    t = now.time()
    if time(9, 30) <= t < time(16, 0):
        return "OPEN"
    elif time(4, 0) <= t < time(9, 30):
        return "PRE-MARKET"
    elif time(16, 0) <= t < time(20, 0):
        return "AFTER-HOURS"
    return "CLOSED"

def get_et_timestamp() -> str:
    et = pytz.timezone("America/New_York")
    return datetime.now(et).strftime("%Y-%m-%d %H:%M:%S ET")

print(f"Market status: {market_status()}")
```

For crypto tickers (e.g. `BTC-USD`, `ETH-USD`), the market is always open — skip the hours check.

## Alert Format

When sending a price alert to the user, include all of the following fields.
All prices should be displayed in **Canadian dollars (CAD)** using the `C$` prefix.
For US-listed tickers, convert to CAD using the `CADUSD=X` forex rate from Yahoo Finance.

```
PRICE ALERT — {TICKER}
Current price : C${current_price:.2f}
Alert threshold: {above/below} C${threshold:.2f}
Market status : {OPEN | PRE-MARKET | AFTER-HOURS | CLOSED}
Triggered at  : {YYYY-MM-DD HH:MM:SS ET}
```

Example:

```
PRICE ALERT — SHOP.TO
Current price : C$132.47
Alert threshold: below C$135.00
Market status : OPEN
Triggered at  : 2026-03-06 10:14:32 ET
```

Always include market status so the user understands the liquidity context of the price.

## Market Hours

| Session | Hours (ET) | Notes |
|---------|-----------|-------|
| Pre-market | 4:00 AM – 9:30 AM | Lower liquidity, wider spreads |
| Regular | 9:30 AM – 4:00 PM | Main session |
| After-hours | 4:00 PM – 8:00 PM | Lower liquidity, wider spreads |
| Crypto | 24/7 | No market close — always active |

US equities trade Monday–Friday only (excluding US market holidays).

## Watchlist File

Alerts and the tracked ticker list are stored in `watchlist.json` at the root of the workspace:

```json
{
  "tickers": ["AAPL", "MSFT", "BTC-USD"],
  "alerts": [
    { "ticker": "AAPL", "above": 200 },
    { "ticker": "AAPL", "below": 150 },
    { "ticker": "BTC-USD", "above": 100000 }
  ]
}
```

- `tickers` — Yahoo Finance ticker symbols included in every watchlist scan
- `alerts` — threshold objects; each has a `ticker` and at least one of `above` or `below`; both can be set on the same entry
- Read this file fresh on every heartbeat — changes take effect immediately without restarting
- Update it whenever the user adds/removes a ticker or changes a threshold

## Currency — Canadian Dollars (CAD)

All prices, alerts, and portfolio values MUST be displayed in **Canadian dollars (C$)**.

- `.TO` tickers (TSX-listed) are already priced in CAD — use as-is
- US-listed tickers (AAPL, MSFT, etc.) must be converted to CAD using the live `CADUSD=X` rate
- Crypto tickers (BTC-USD, ETH-USD) must also be converted to CAD
- Always show the `C$` prefix, never bare `$`

### CAD conversion helper

```python
import yfinance as yf

def get_usd_to_cad() -> float:
    """Fetch the current USD→CAD exchange rate."""
    fx = yf.Ticker("CADUSD=X")
    rate = fx.fast_info.last_price
    if rate is None:
        hist = fx.history(period="2d", auto_adjust=True)
        rate = float(hist["Close"].dropna().iloc[-1])
    # CADUSD=X returns how many USD per 1 CAD, so invert it
    return 1.0 / rate

def to_cad(usd_price: float) -> float:
    """Convert a USD price to CAD."""
    return usd_price * get_usd_to_cad()
```

## Ethical Screening (Halal Filter)

The user has religious restrictions. The following sectors are **permanently excluded**
from all watchlists, scans, alerts, and recommendations:

| Excluded Sector | Examples |
|----------------|----------|
| Alcohol | Breweries, distilleries, wine/beer/spirits companies |
| Arms & Defense | Weapons manufacturers, defense contractors, ammunition |
| Drugs | Recreational cannabis, psychedelics (pharma R&D is OK) |
| Gambling | Casinos, sports betting, lotteries, online gambling |
| Tobacco / Smoking | Cigarettes, e-cigarettes, vaping, smokeless tobacco |
| Vice | Adult entertainment, other vice industries |

**Rules:**
- NEVER add a ticker from an excluded sector to the watchlist
- NEVER display price alerts for excluded tickers
- If the user asks to add an excluded ticker, politely decline and explain why
- If unsure whether a company falls into an excluded category, err on the side of exclusion
- Broad-market ETFs (SPY, QQQ, XIU.TO) are permitted but flag if a large portion of holdings are in excluded sectors
