---
name: moomoo-trader
description: "Places, modifies, and cancels stock/crypto orders through the moomoo OpenAPI. Use when: (1) user says 'buy 10 shares of AAPL', (2) user asks to place a limit order, (3) checking open orders or positions from moomoo, (4) cancelling a pending order. NOT for: price monitoring (use finance-monitor), analysis (use stock-analysis), portfolio tracking from local files (use portfolio-tracker)."
metadata:
  {
    "openclaw":
      {
        "emoji": "🔄",
        "requires": { "bins": ["python3"], "pip": ["moomoo-api"] },
      },
  }
---

# moomoo Trader

## When to Use

- User explicitly asks to buy or sell a stock, ETF, or crypto
- Placing limit, market, or stop orders
- Checking open orders or filled order history from the broker
- Cancelling or modifying a pending order
- Querying real account positions and balances from moomoo (vs local portfolio.json)

## When NOT to Use

- Price monitoring or alerts — use `finance-monitor`
- Technical/fundamental analysis — use `stock-analysis`
- Local portfolio P&L tracking — use `portfolio-tracker`
- Any action when `MOOMOO_TRADE_ENV` is not confirmed — check env first

## Safety Rules (Non-Negotiable)

1. **NEVER place a live order without explicit user confirmation.** Always show the order details and ask "Confirm this order? (yes/no)" before executing.
2. **Always check MOOMOO_TRADE_ENV first.** If it's `SIMULATE`, say "Paper trading mode". If it's `REAL`, warn prominently: "LIVE TRADING — real money at risk."
3. **Respect the 2% risk limit.** Calculate position size against total portfolio value. Refuse orders that exceed the user's `max_risk_per_trade_pct` from USER.md.
4. **Never place market orders on illiquid stocks.** Use limit orders by default.
5. **Log every order** to `paper-trading/trades.md` (if simulated) or `portfolio/positions.md` (if live).

## Setup

```bash
pip install moomoo-api
```

OpenD must be running on the host machine.

## Shared Helper

Use this helper in ALL moomoo scripts to avoid repeating env var setup. It validates
`MOOMOO_TRADE_ENV` and refuses to default to REAL on typos.

```python
import os
from moomoo import TrdEnv, SecurityFirm

def get_moomoo_config():
    """Load and validate moomoo connection config from environment variables."""
    host = os.environ.get("MOOMOO_OPEND_HOST", "127.0.0.1")

    port_str = os.environ.get("MOOMOO_OPEND_PORT", "11111")
    try:
        port = int(port_str)
    except ValueError:
        raise ValueError(f"Invalid MOOMOO_OPEND_PORT: {port_str}")

    trade_env_str = os.environ.get("MOOMOO_TRADE_ENV", "SIMULATE").upper()
    if trade_env_str not in ("SIMULATE", "REAL"):
        raise ValueError(f"MOOMOO_TRADE_ENV must be SIMULATE or REAL, got: {trade_env_str}")
    trd_env = TrdEnv.SIMULATE if trade_env_str == "SIMULATE" else TrdEnv.REAL

    security_firm = os.environ.get("MOOMOO_SECURITY_FIRM", "FUTUINC")
    sec_firm = getattr(SecurityFirm, security_firm, SecurityFirm.FUTUINC)

    return {
        "host": host,
        "port": port,
        "trd_env": trd_env,
        "sec_firm": sec_firm,
        "trade_env_str": trade_env_str,
    }
```

## Key Commands

### Check connection and trading environment

```python
from moomoo import OpenQuoteContext

cfg = get_moomoo_config()  # use helper above
print(f"Trade environment: {cfg['trade_env_str']}")
print(f"OpenD: {cfg['host']}:{cfg['port']}")

if cfg['trade_env_str'] == "REAL":
    print("WARNING: LIVE TRADING MODE — real money at risk!")

quote_ctx = OpenQuoteContext(host=cfg['host'], port=cfg['port'])
ret, data = quote_ctx.get_global_state()
print(f"Connection: {'OK' if ret == 0 else 'FAILED'}")
quote_ctx.close()
```

### Get account positions from moomoo

```python
from moomoo import OpenSecTradeContext, TrdMarket

cfg = get_moomoo_config()  # use helper above

trd_ctx = OpenSecTradeContext(
    host=cfg['host'], port=cfg['port'], security_firm=cfg['sec_firm'],
    filter_trdmarket=TrdMarket.US
)

ret, data = trd_ctx.position_list_query(trd_env=cfg['trd_env'])
if ret == 0:
    if data.empty:
        print("No open positions.")
    else:
        for _, row in data.iterrows():
            print(f"  {row['code']}: {row['qty']} shares @ ${row['cost_price']:.2f} | P&L: ${row['pl_val']:.2f} ({row['pl_ratio']*100:.1f}%)")
else:
    print(f"Error: {data}")

trd_ctx.close()
```

### Get account balance

```python
from moomoo import OpenSecTradeContext, TrdMarket

cfg = get_moomoo_config()

trd_ctx = OpenSecTradeContext(
    host=cfg['host'], port=cfg['port'], security_firm=cfg['sec_firm'],
    filter_trdmarket=TrdMarket.US
)

ret, data = trd_ctx.accinfo_query(trd_env=cfg['trd_env'])
if ret == 0:
    row = data.iloc[0]
    print(f"Total Assets : ${row['total_assets']:.2f}")
    print(f"Cash         : ${row['cash']:.2f}")
    print(f"Market Value : ${row['market_val']:.2f}")
    print(f"Buying Power : ${row['power']:.2f}")
else:
    print(f"Error: {data}")

trd_ctx.close()
```

### Place a limit buy order

```python
from moomoo import OpenSecTradeContext, TrdSide, OrderType, TrdMarket

cfg = get_moomoo_config()

# Order parameters — ALWAYS confirm with user before executing
TICKER = "US.AAPL"        # moomoo format: market prefix + ticker
SIDE = TrdSide.BUY
QTY = 10
PRICE = 185.00            # limit price
ORDER_TYPE = OrderType.NORMAL  # NORMAL = limit order

trd_ctx = OpenSecTradeContext(
    host=cfg['host'], port=cfg['port'], security_firm=cfg['sec_firm'],
    filter_trdmarket=TrdMarket.US
)

ret, data = trd_ctx.place_order(
    price=PRICE,
    qty=QTY,
    code=TICKER,
    trd_side=SIDE,
    order_type=ORDER_TYPE,
    trd_env=cfg['trd_env']
)

if ret == 0:
    order_id = data['order_id'].iloc[0]
    print(f"Order placed: {SIDE.name} {QTY} {TICKER} @ ${PRICE:.2f}")
    print(f"Order ID: {order_id}")
    print(f"Environment: {cfg['trade_env_str']}")
else:
    print(f"Order failed: {data}")

trd_ctx.close()
```

### Place a market sell order

```python
from moomoo import OpenSecTradeContext, TrdSide, OrderType, TrdMarket

cfg = get_moomoo_config()

TICKER = "US.AAPL"
SIDE = TrdSide.SELL
QTY = 10

trd_ctx = OpenSecTradeContext(
    host=cfg['host'], port=cfg['port'], security_firm=cfg['sec_firm'],
    filter_trdmarket=TrdMarket.US
)

# Market order: price=0.01 is a convention for market orders in moomoo API
ret, data = trd_ctx.place_order(
    price=0.01,
    qty=QTY,
    code=TICKER,
    trd_side=SIDE,
    order_type=OrderType.MARKET,
    trd_env=cfg['trd_env']
)

if ret == 0:
    print(f"Market sell placed: {QTY} {TICKER}")
    print(f"Order ID: {data['order_id'].iloc[0]}")
else:
    print(f"Order failed: {data}")

trd_ctx.close()
```

### Cancel an order

```python
from moomoo import OpenSecTradeContext, TrdMarket

cfg = get_moomoo_config()
ORDER_ID = "YOUR_ORDER_ID"  # from place_order response

trd_ctx = OpenSecTradeContext(
    host=cfg['host'], port=cfg['port'], security_firm=cfg['sec_firm'],
    filter_trdmarket=TrdMarket.US
)

ret, data = trd_ctx.modify_order(
    modify_order_op=0,  # 0 = cancel
    order_id=ORDER_ID,
    qty=0, price=0,
    trd_env=cfg['trd_env']
)

if ret == 0:
    print(f"Order {ORDER_ID} cancelled.")
else:
    print(f"Cancel failed: {data}")

trd_ctx.close()
```

### List open orders

```python
from moomoo import OpenSecTradeContext, TrdMarket

cfg = get_moomoo_config()

trd_ctx = OpenSecTradeContext(
    host=cfg['host'], port=cfg['port'], security_firm=cfg['sec_firm'],
    filter_trdmarket=TrdMarket.US
)

ret, data = trd_ctx.order_list_query(trd_env=cfg['trd_env'])
if ret == 0:
    if data.empty:
        print("No open orders.")
    else:
        for _, row in data.iterrows():
            print(f"  [{row['order_status']}] {row['trd_side']} {row['qty']} {row['code']} @ ${row['price']:.2f} | ID: {row['order_id']}")
else:
    print(f"Error: {data}")

trd_ctx.close()
```

## Ticker Format

moomoo uses market-prefixed tickers:

| Market | Format | Example |
|--------|--------|---------|
| US stocks | `US.TICKER` | `US.AAPL`, `US.NVDA` |
| Hong Kong | `HK.TICKER` | `HK.00700` |
| Canada (TSX) | Not directly supported via OpenAPI — use US-listed Canadian stocks or yfinance for TSX prices |

When the user says "buy AAPL", convert to `US.AAPL` before calling the API.

## Order Confirmation Template

Before executing ANY order, present this to the user and wait for confirmation:

```
ORDER CONFIRMATION
  Action      : BUY / SELL
  Ticker      : US.AAPL (Apple Inc.)
  Quantity    : 10 shares
  Order Type  : LIMIT @ $185.00
  Est. Total  : $1,850.00
  Environment : SIMULATE (paper trading)
  Risk Check  : 3.7% of portfolio ($50,000) — within 2% per-trade limit? NO — reduce size

  Confirm? (yes / no)
```

NEVER skip this confirmation step. If the user says "just do it" or "auto-trade", still confirm the first time and explain that confirmation is a safety requirement.

## Post-Order Logging

After every executed order, log it:

- **Paper trading**: append to `paper-trading/trades.md`
- **Live trading**: append to `portfolio/positions.md` AND update `portfolio.json`

Log format:
```
| 2026-03-07 10:30 ET | AAPL | BUY | 10 | C$255.00 | C$2,550.00 | Limit order filled | Order ID: 12345 |
```

## Currency — Canadian Dollars (CAD)

All order confirmations, position values, and balance displays MUST use **Canadian dollars (C$)**.
Convert USD amounts from moomoo to CAD using the `CADUSD=X` forex rate before displaying to the user.

## Ethical Screening (Halal Filter)

**NEVER place orders** for tickers in excluded sectors: alcohol, arms/defense, drugs (recreational), gambling, tobacco/smoking, vice.
If the user requests a trade on an excluded ticker:
1. Refuse the order
2. Explain that the ticker is in an excluded sector per their religious screening preferences
3. Suggest a halal-compliant alternative if possible
