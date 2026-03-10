# Momentum Rules

## What Momentum Means Here

Momentum = a stock is already moving in the right direction AND volume confirms real interest behind the move.

A price moving up on thin volume is noise. A price moving up with volume 1.5–2x the 20-day average is a signal that institutions or informed participants are involved. That combination is what this system targets.

Momentum is a supporting signal only. It never initiates a trade. It adds weight to a trade that already qualifies on core signals.

---

## The 4 Momentum Signals (exact thresholds)

Each signal that qualifies adds +0.5 to the trade score. Maximum total momentum contribution: **+1.0** (two signals max, even if all four fire).

| Signal | Threshold | What it indicates |
|---|---|---|
| **Price momentum** | Stock up >3% in last 5 trading days AND currently above its 20-day MA | Short-term trend is intact and supported by the moving average |
| **Relative strength** | Stock outperforming SPY by >5% over the last 20 trading days | Stock is leading the market, not just riding the tide |
| **Volume momentum** | Volume at least 1.5x the 20-day average volume, for 3 or more consecutive days | Sustained institutional accumulation, not a one-day spike |
| **52-week high proximity** | Price within 10% below the 52-week high, with volume above average | Breakout setup — price is approaching a key resistance level with buying pressure |

---

## Position Sizing — Momentum-Boosted Trades

Normal position sizing: 2% portfolio risk per trade.

If a trade's score was boosted by any momentum signal (`momentum_boosted = true`), the position sizing is **capped at 1% portfolio risk** — half the normal size.

Why: momentum trades move fast in both directions. The higher false positive rate means losses can come quickly. Smaller size preserves capital when the signal turns out to be noise.

This cap applies even if score is high. A score of 5 with momentum boost still gets 1% risk sizing.

---

## The Core Rule

**Momentum adds to a trade. It never starts one.**

Momentum scoring only runs after:
1. Halal check passes (non-negotiable prerequisite)
2. At least 2 core signals are already confirmed (RSI < 45, positive news, price above 20MA, volume)

If a stock looks great on momentum but has RSI of 72 and mixed news, skip it entirely. Momentum alone is not a reason to buy.

---

## Why Momentum Is Kept Small

Momentum strategies have a well-documented problem: they work well in trending markets and fail badly in choppy or reversing markets. A stock up 4% in 5 days can just as easily be down 4% in the next 5 days.

By capping momentum's contribution at +1.0 out of a total buy threshold of 3, it can tip a borderline trade over the line but cannot manufacture a trade from weak core signals.

The position size cap adds a second layer of protection — even if momentum fires on a false signal, the loss is bounded.

---

## Python Snippet — Calculating Momentum Signals with yfinance

```python
import yfinance as yf
import pandas as pd

def get_momentum_signals(ticker: str) -> dict:
    """
    Returns momentum signal flags and the total momentum score boost.
    Max boost: +1.0 (capped even if multiple signals fire).
    """
    stock = yf.Ticker(ticker)
    spy = yf.Ticker("SPY")

    # Pull 60 days of daily data (enough for 20-day MA + 20-day relative strength)
    hist = stock.history(period="60d")
    spy_hist = spy.history(period="60d")

    if hist.empty or len(hist) < 22:
        return {"error": "insufficient data", "momentum_boost": 0, "momentum_boosted": False}

    signals = {}

    # --- Signal 1: Price momentum (5-day return > 3% AND above 20-day MA) ---
    price_now = hist["Close"].iloc[-1]
    price_5d_ago = hist["Close"].iloc[-6]  # 5 trading days back
    five_day_return = (price_now - price_5d_ago) / price_5d_ago

    ma_20 = hist["Close"].rolling(window=20).mean().iloc[-1]
    signals["price_momentum"] = (five_day_return > 0.03) and (price_now > ma_20)

    # --- Signal 2: Relative strength vs SPY over 20 days ---
    stock_20d_return = (hist["Close"].iloc[-1] - hist["Close"].iloc[-21]) / hist["Close"].iloc[-21]
    spy_20d_return = (spy_hist["Close"].iloc[-1] - spy_hist["Close"].iloc[-21]) / spy_hist["Close"].iloc[-21]
    relative_strength = stock_20d_return - spy_20d_return
    signals["relative_strength"] = relative_strength > 0.05

    # --- Signal 3: Volume momentum (1.5x 20-day avg volume for 3+ consecutive days) ---
    vol_avg_20 = hist["Volume"].rolling(window=20).mean()
    recent_vols = hist["Volume"].iloc[-3:]
    recent_avgs = vol_avg_20.iloc[-3:]
    consecutive_high_vol = all(
        recent_vols.iloc[i] >= 1.5 * recent_avgs.iloc[i]
        for i in range(3)
    )
    signals["volume_momentum"] = consecutive_high_vol

    # --- Signal 4: 52-week high proximity (within 10%, above-average volume) ---
    high_52w = hist["High"].rolling(window=252).max().iloc[-1]
    # Use available data if less than 252 days
    if len(hist) < 252:
        high_52w = hist["High"].max()
    pct_from_high = (high_52w - price_now) / high_52w
    vol_today = hist["Volume"].iloc[-1]
    avg_vol = vol_avg_20.iloc[-1]
    signals["near_52w_high"] = (pct_from_high <= 0.10) and (vol_today > avg_vol)

    # --- Score: +0.5 per signal, cap at +1.0 ---
    raw_boost = sum(0.5 for s in signals.values() if s)
    momentum_boost = min(raw_boost, 1.0)
    momentum_boosted = momentum_boost > 0

    # Build a human-readable log string
    triggered = [name for name, fired in signals.items() if fired]
    log_str = f"Momentum signals fired: {triggered} | boost: +{momentum_boost}"

    return {
        "signals": signals,
        "triggered": triggered,
        "momentum_boost": momentum_boost,
        "momentum_boosted": momentum_boosted,
        "log": log_str,
        # Metadata for transparency
        "five_day_return_pct": round(five_day_return * 100, 2),
        "relative_strength_vs_spy_pct": round(relative_strength * 100, 2),
        "price_vs_20ma": round(price_now / ma_20, 4),
    }


# Example usage
if __name__ == "__main__":
    result = get_momentum_signals("NVDA")
    print(result["log"])
    if result["momentum_boosted"]:
        print("Position size cap: 1% portfolio risk (momentum-boosted trade)")
    else:
        print("Normal position sizing: 2% portfolio risk")
```

### How to integrate into the scan loop

```python
# Inside Step 3 of AUTONOMOUS_TRADING.md scan loop
core_score = calculate_core_score(ticker)  # RSI, news, MA, volume — returns 0-5

if core_score >= 2 and halal_passed:
    momentum = get_momentum_signals(ticker)
    final_score = core_score + momentum["momentum_boost"]
    momentum_boosted = momentum["momentum_boosted"]
    log(momentum["log"])
else:
    final_score = core_score
    momentum_boosted = False

# Apply momentum position size cap downstream
if momentum_boosted:
    risk_pct = 0.01  # 1% cap
else:
    risk_pct = 0.02  # normal 2%
```
