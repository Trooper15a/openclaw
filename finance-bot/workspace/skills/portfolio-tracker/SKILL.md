---
name: portfolio-tracker
description: "Tracks stock/crypto portfolio holdings, calculates real-time P&L, tracks performance vs benchmarks, generates performance reports. Use when: user asks about portfolio value, P&L, returns, how holdings are performing. NOT for: placing trades, deep technical analysis (use stock-analysis)."
metadata:
  {
    "openclaw":
      {
        "emoji": "💼",
        "requires": { "bins": ["python3"] },
      },
  }
---

# Portfolio Tracker

## When to Use

- User asks for current portfolio value or total account balance
- User wants to know P&L (profit and loss) on any position or the full portfolio
- User asks how holdings are performing vs the S&P 500 or another benchmark
- User wants a position sizing review or wants to know their largest holdings
- User asks for a daily or weekly portfolio summary report

## Portfolio File Format

The portfolio is stored in `portfolio.json` in the workspace root. The bot reads and writes this file to track positions.

```json
{
  "positions": [
    {"ticker": "SHOP.TO", "shares": 15, "avg_cost": 120.00, "currency": "CAD"},
    {"ticker": "RY.TO", "shares": 20, "avg_cost": 145.00, "currency": "CAD"},
    {"ticker": "BTC-USD", "shares": 0.5, "avg_cost": 55000.00, "currency": "CAD"}
  ],
  "cash": 5000.00,
  "paper_trading": true,
  "created": "2026-03-01"
}
```

Fields:
- `ticker`: Yahoo Finance ticker symbol (use `BTC-USD` for Bitcoin, `ETH-USD` for Ethereum, etc.)
- `shares`: number of shares or units held
- `avg_cost`: average cost basis per share/unit in the position currency
- `currency`: position currency — use `"CAD"` (all values displayed in Canadian dollars)
- `cash`: uninvested cash balance
- `paper_trading`: `true` for simulated positions, `false` for real money
- `created`: date portfolio tracking began (used for inception P&L calculations)

## Key Commands

### Load portfolio and fetch current prices

```python
import json
import yfinance as yf

# Fix: wrap file load in try/except for missing file
try:
    with open("portfolio.json") as f:
        portfolio = json.load(f)
except FileNotFoundError:
    print("Error: portfolio.json not found. Create it first using the Portfolio File Format above.")
    raise SystemExit(1)

positions = portfolio["positions"]
tickers = [p["ticker"] for p in positions]

# Fix: add progress=False to suppress download progress bar
data = yf.download(tickers, period="2d", auto_adjust=True, progress=False)["Close"]

# Fix: handle single-ticker (flat DataFrame) vs multi-ticker (MultiIndex) difference
# and add .dropna() before .iloc[-1] to guard against empty rows
current_prices = {}
for ticker in tickers:
    if len(tickers) == 1:
        current_prices[ticker] = float(data.dropna().iloc[-1])
    else:
        current_prices[ticker] = float(data[ticker].dropna().iloc[-1])
```

### Calculate total value, cost, P&L, and P&L %

```python
total_value = portfolio["cash"]
total_cost = portfolio["cash"]  # cash is at cost

for p in positions:
    ticker = p["ticker"]
    shares = p["shares"]
    avg_cost = p["avg_cost"]
    price = current_prices[ticker]

    position_value = shares * price
    position_cost = shares * avg_cost
    position_pnl = position_value - position_cost
    position_pnl_pct = (position_pnl / position_cost) * 100

    total_value += position_value
    total_cost += position_cost

    print(f"{ticker}: {shares} shares @ C${price:.2f} = C${position_value:,.2f} | P&L: C${position_pnl:+,.2f} ({position_pnl_pct:+.2f}%)")

total_pnl = total_value - total_cost
total_pnl_pct = (total_pnl / total_cost) * 100
print(f"\nTotal Portfolio Value: C${total_value:,.2f}")
print(f"Total P&L: C${total_pnl:+,.2f} ({total_pnl_pct:+.2f}%)")
```

### Compare to SPY (S&P 500 benchmark) over same period

```python
import yfinance as yf

created = portfolio["created"]  # e.g. "2026-03-01"

# Fix: add progress=False; add .dropna() before positional access
spy = yf.download("SPY", start=created, auto_adjust=True, progress=False)["Close"].dropna()
spy_return = ((spy.iloc[-1] - spy.iloc[0]) / spy.iloc[0]) * 100

print(f"SPY return since {created}: {spy_return:+.2f}%")
print(f"Portfolio return since {created}: {total_pnl_pct:+.2f}%")
print(f"Alpha: {total_pnl_pct - spy_return:+.2f}%")
```

## Daily Report Format

Format the daily portfolio summary as follows:

```
PORTFOLIO SUMMARY — 2026-03-06  (All values in CAD)

Total Value:     C$52,340.00
Day's Change:    +C$420.00 (+0.81%)
Total P&L:       +C$2,340.00 (+4.68%) since inception

TOP GAINERS
  SHOP.TO  +3.21%   C$1,240.00 gain
  BTC-USD  +1.85%   C$380.00 gain

TOP LOSERS
  RY.TO    -0.42%   -C$63.00 loss
  ETH-USD  -1.10%   -C$55.00 loss

POSITIONS
  SHOP.TO  15 sh  @ C$135.20  | Cost: C$120.00 | P&L: +C$228.00 (+12.7%)
  RY.TO    20 sh  @ C$152.00  | Cost: C$145.00 | P&L: +C$140.00 (+4.8%)
  BTC-USD   0.5   @ C$112,000 | Cost: C$55,000 | P&L: +C$28,500 (+51.8%)
  Cash: C$5,000.00

Benchmark (XIU.TO since inception): +8.3%
Portfolio alpha: +4.68% - 8.3% = -3.62%
```

## Paper Trading Mode

When `paper_trading: true` in `portfolio.json`, all positions are simulated — no real money is involved. The bot must:

1. Confirm paper vs live mode at the start of every session: say "Running in PAPER TRADING mode — no real money at risk" or "Running in LIVE mode — real money."
2. Never suggest that paper gains or losses reflect actual financial results.
3. When switching from paper to live mode, warn the user explicitly and require manual confirmation by editing `portfolio.json`.

Paper trading is the default for new portfolios. Set `"paper_trading": false` only after the user explicitly confirms they are tracking real positions.

## Risk Metrics

Always calculate and include the following risk metrics in full portfolio reports:

- **Largest single position %**: `(position_value / total_value) * 100` — flag if any position exceeds 20% of portfolio
- **Sector concentration**: group tickers by sector using `yf.Ticker(ticker).info.get("sector")` — flag if any sector exceeds 40%
- **Unrealized loss positions**: list all positions with negative P&L — note these as potential tax loss harvesting candidates (user should consult a tax advisor)
- **Cash allocation %**: `(cash / total_value) * 100` — note if cash is very high (>30%) or very low (<5%)
