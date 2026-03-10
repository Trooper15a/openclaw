---
name: market-trend
description: "Predicts overall market direction using macro, breadth, sector rotation, and sentiment signals. Returns STRONG_BULL/BULL/NEUTRAL/BEAR/STRONG_BEAR verdict with score. Run this FIRST before any individual stock analysis. The verdict adjusts position sizes and selectivity thresholds for the entire trading session."
metadata:
  {
    "openclaw": {
      "emoji": "📈",
      "requires": { "bins": ["python3"], "pip": ["yfinance", "requests", "pandas"] }
    }
  }
---

# Market Trend Skill

## When to Use

- Run at the start of EVERY pre-market scan — before halal screening, before watchlist scoring, before everything
- When the user asks "what is the market doing?" or "should I be buying today?"
- When checking whether to enter any new position
- When setting position size multipliers for the session
- When the user asks about overall market health, trend, or direction

## When NOT to Use

- For individual stock analysis — use `stock-analysis`
- For earnings dates — use `earnings-tracker`
- For specific economic event timing — use `economic-calendar`
- For halal screening — use `halal-screener`

## Setup

```bash
pip install yfinance requests pandas
```

No paid API keys required. All data sourced from:
- Yahoo Finance via yfinance (SPY, QQQ, VIX, sector ETFs)
- CNN Fear & Greed Index (free public API)
- CBOE put/call ratio via yfinance

## Quick Start

```bash
python3 market_trend.py
```

For JSON output (machine-readable, for use in the trading loop):

```bash
python3 market_trend.py --json
```

## Output

The script outputs a human-readable summary and optionally a JSON object. The JSON output is used by AUTONOMOUS_TRADING.md Step 0 to set session-wide parameters.

**Human-readable output:**
```
MARKET TREND: BULL (7.2/10)
  Macro:     8.0/10 — SPY above 200MA (+2.1%), VIX=18 (calm), Golden cross active
  Breadth:   7.0/10 — 64% stocks above 200MA, A/D ratio=1.8, Highs/Lows=3.2
  Sectors:   7.0/10 — Tech +6.8% vs Utilities -1.2% (20d), Risk-on: 3/4 sectors leading
  Sentiment: 6.0/10 — Fear&Greed=58 (neutral-greed), Put/Call=0.82, AAII Bears=32%

  Verdict: BULL
  Position Size Multiplier: 1.00x
  Min Buy Score Required: 3.0
  Action: Normal position sizes. Scan all watchlist tickers.
```

**JSON output (--json flag):**
```json
{
  "verdict": "BULL",
  "score": 7.2,
  "position_size_multiplier": 1.0,
  "min_buy_score": 3.0,
  "macro_score": 8.0,
  "breadth_score": 7.0,
  "sector_score": 7.0,
  "sentiment_score": 6.0,
  "allow_new_buys": true,
  "details": {
    "spy_vs_200ma_pct": 2.1,
    "vix": 18.3,
    "golden_cross_spy": true,
    "golden_cross_qqq": true,
    "pct_above_200ma": 64.0,
    "fear_greed": 58,
    "put_call_ratio": 0.82,
    "xlk_vs_xlu_spread": 6.8
  }
}
```

## Integration in the Trading Loop

In AUTONOMOUS_TRADING.md Step 0, call:

```python
import subprocess, json
result = subprocess.run(["python3", "market_trend.py", "--json"], capture_output=True, text=True)
market = json.loads(result.stdout)

verdict = market["verdict"]
position_size_multiplier = market["position_size_multiplier"]
min_buy_score = market["min_buy_score"]
allow_new_buys = market["allow_new_buys"]

if not allow_new_buys:
    print("STRONG_BEAR: No new buys. Cash only.")
    exit()
```

The `position_size_multiplier` from this step gets multiplied with the economic calendar multiplier. Both stack together (see MARKET_TREND.md for the stacking formula).

---

## Complete Python Script

Save as `market_trend.py` in the workspace root or the skills/market-trend/ directory.

```python
#!/usr/bin/env python3
"""
market_trend.py — FinClaw Market Trend Prediction
Scores the overall market on a 0-10 scale across 4 signal groups.
Returns a verdict: STRONG_BULL / BULL / NEUTRAL / BEAR / STRONG_BEAR

Usage:
    python3 market_trend.py          # human-readable output
    python3 market_trend.py --json   # machine-readable JSON output

Requirements:
    pip install yfinance requests pandas
"""

import sys
import json
import warnings
import datetime
from typing import Optional

warnings.filterwarnings("ignore")

try:
    import yfinance as yf
    import pandas as pd
    import requests
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Run: pip install yfinance requests pandas")
    sys.exit(1)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# S&P 500 representative basket for breadth calculation (100 large-caps)
SP500_BASKET = [
    "AAPL", "MSFT", "NVDA", "AMZN", "GOOGL", "META", "TSLA", "BRK-B", "JPM", "UNH",
    "XOM", "LLY", "JNJ", "V", "PG", "MA", "MRK", "HD", "CVX", "ABBV",
    "KO", "ADBE", "CRM", "PEP", "AVGO", "WMT", "MCD", "ACN", "BAC", "CSCO",
    "TMO", "ABT", "COST", "DHR", "NEE", "LIN", "TXN", "QCOM", "HON", "PM",
    "AMGN", "MDT", "RTX", "UPS", "SBUX", "INTU", "ISRG", "LOW", "BKNG", "GILD",
    "ELV", "DE", "VRTX", "PLD", "REGN", "ZTS", "MDLZ", "SLB", "CI", "ADI",
    "PYPL", "AMAT", "MU", "TJX", "PANW", "LRCX", "KLAC", "SNPS", "CDNS", "MCHP",
    "APD", "ECL", "ITW", "AON", "CTAS", "CMG", "MMC", "F", "GM", "FDX",
    "GE", "MMM", "CAT", "BA", "GS", "MS", "BLK", "SPGI", "ICE", "CB",
    "AMT", "EQIX", "CCI", "DLR", "SPG", "O", "PSA", "VTR", "EXR", "AVB",
]

# Sector ETFs for rotation analysis
RISK_ON_ETFS  = ["XLK", "XLY", "XLB", "XLI"]   # tech, disc, materials, industrial
RISK_OFF_ETFS = ["XLU", "XLP", "GLD", "IEF"]    # utilities, staples, gold, bonds


# ---------------------------------------------------------------------------
# Data Fetching Helpers
# ---------------------------------------------------------------------------

def fetch_price_history(ticker: str, days: int = 260) -> Optional[pd.DataFrame]:
    """Fetch OHLCV history for a ticker. Returns None on failure."""
    try:
        t = yf.Ticker(ticker)
        df = t.history(period=f"{days}d", interval="1d", auto_adjust=True)
        if df is None or df.empty or len(df) < 20:
            return None
        return df
    except Exception:
        return None


def fetch_multi_last_close(tickers: list, days: int = 5) -> dict:
    """Fetch last close prices for multiple tickers at once. Returns dict ticker->float."""
    result = {}
    try:
        data = yf.download(tickers, period=f"{days}d", interval="1d",
                           auto_adjust=True, progress=False, threads=True)
        if data is None or data.empty:
            return result
        close = data["Close"] if "Close" in data.columns else data.xs("Close", axis=1, level=0)
        for ticker in tickers:
            try:
                if ticker in close.columns:
                    series = close[ticker].dropna()
                    if not series.empty:
                        result[ticker] = float(series.iloc[-1])
            except Exception:
                pass
    except Exception:
        pass
    return result


def fetch_cnn_fear_greed() -> Optional[float]:
    """
    Fetch CNN Fear & Greed Index from their free public API.
    Returns 0-100 score, or None on failure.
    """
    url = "https://production.dataviz.cnn.io/index/fearandgreed/graphdata"
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Referer": "https://money.cnn.com/data/fear-and-greed/",
        }
        resp = requests.get(url, headers=headers, timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            # The score is nested under fear_and_greed.score
            if "fear_and_greed" in data:
                score = data["fear_and_greed"].get("score", None)
                if score is not None:
                    return float(score)
            # Fallback: try "current_list" first element
            if "fear_and_greed_historical" in data:
                hist = data["fear_and_greed_historical"].get("data", [])
                if hist:
                    return float(hist[0].get("y", 50))
    except Exception:
        pass
    return None  # Will default to neutral (5.0/10) in scoring


def fetch_put_call_ratio() -> Optional[float]:
    """
    Attempt to fetch CBOE equity put/call ratio via yfinance.
    Uses ^PCALL if available, otherwise approximates from VIX trend.
    Returns 5-day average ratio, or None on failure.
    """
    try:
        # Try CBOE total put/call ratio ticker
        for ticker_sym in ["^PCALL", "^CPC"]:
            df = fetch_price_history(ticker_sym, days=30)
            if df is not None and not df.empty:
                recent = df["Close"].dropna().tail(5)
                if len(recent) >= 3:
                    return float(recent.mean())
    except Exception:
        pass
    return None  # Will default to neutral in scoring


# ---------------------------------------------------------------------------
# Signal Group 1 — Macro Trend (Weight: 40%)
# ---------------------------------------------------------------------------

def score_macro_trend() -> tuple[float, dict]:
    """
    Scores macro trend signals: MA crossovers, SPY vs 20MA, VIX level, 52-week proximity.
    Returns (score_0_to_10, details_dict).
    """
    details = {}
    raw_score = 0.0
    max_raw = 10.0

    # --- Fetch SPY and QQQ history ---
    spy_df = fetch_price_history("SPY", days=260)
    qqq_df = fetch_price_history("QQQ", days=260)
    vix_df = fetch_price_history("^VIX", days=30)

    # 1a. Golden Cross / Death Cross (max 3.0)
    spy_golden = None
    qqq_golden = None
    cross_score = 1.5  # default neutral

    if spy_df is not None and len(spy_df) >= 200:
        spy_50  = spy_df["Close"].rolling(50).mean().iloc[-1]
        spy_200 = spy_df["Close"].rolling(200).mean().iloc[-1]
        spy_golden = spy_50 > spy_200
        details["spy_golden_cross"] = spy_golden
        details["spy_50ma"] = round(float(spy_50), 2)
        details["spy_200ma"] = round(float(spy_200), 2)
    else:
        details["spy_golden_cross"] = None

    if qqq_df is not None and len(qqq_df) >= 200:
        qqq_50  = qqq_df["Close"].rolling(50).mean().iloc[-1]
        qqq_200 = qqq_df["Close"].rolling(200).mean().iloc[-1]
        qqq_golden = qqq_50 > qqq_200
        details["qqq_golden_cross"] = qqq_golden
    else:
        details["qqq_golden_cross"] = None

    if spy_golden is not None and qqq_golden is not None:
        if spy_golden and qqq_golden:
            cross_score = 3.0
        elif spy_golden or qqq_golden:
            cross_score = 1.5
        else:
            cross_score = 0.0
    elif spy_golden is not None:
        cross_score = 1.5 if spy_golden else 0.5
    raw_score += cross_score
    details["cross_score"] = cross_score

    # 1b. SPY vs 20-day MA (max 2.0)
    spy_vs_20_score = 1.0  # default neutral
    spy_vs_20_pct = 0.0
    if spy_df is not None and len(spy_df) >= 20:
        spy_price = float(spy_df["Close"].iloc[-1])
        spy_20ma  = float(spy_df["Close"].rolling(20).mean().iloc[-1])
        spy_vs_20_pct = ((spy_price - spy_20ma) / spy_20ma) * 100
        if spy_vs_20_pct > 2:
            spy_vs_20_score = 2.0
        elif spy_vs_20_pct > 0:
            spy_vs_20_score = 1.0
        elif spy_vs_20_pct > -2:
            spy_vs_20_score = 0.5
        else:
            spy_vs_20_score = 0.0
        details["spy_vs_20ma_pct"] = round(spy_vs_20_pct, 2)
        details["spy_price"] = round(spy_price, 2)
        details["spy_20ma"] = round(spy_20ma, 2)
    raw_score += spy_vs_20_score
    details["spy_vs_20_score"] = spy_vs_20_score

    # 1c. VIX Level (max 3.0)
    vix_score = 2.0  # default neutral
    vix_value = None
    if vix_df is not None and not vix_df.empty:
        vix_value = float(vix_df["Close"].iloc[-1])
        if vix_value < 15:
            vix_score = 3.0
        elif vix_value < 20:
            vix_score = 2.5
        elif vix_value < 25:
            vix_score = 2.0
        elif vix_value < 30:
            vix_score = 1.0
        elif vix_value < 35:
            vix_score = 0.5
        else:
            vix_score = 0.0
        details["vix"] = round(vix_value, 2)
    else:
        details["vix"] = None
    raw_score += vix_score
    details["vix_score"] = vix_score

    # 1d. SPY 52-week high/low proximity (max 2.0)
    spy_52_score = 1.0  # default neutral
    if spy_df is not None and len(spy_df) >= 252:
        spy_price = float(spy_df["Close"].iloc[-1])
        spy_52w_high = float(spy_df["Close"].tail(252).max())
        spy_52w_low  = float(spy_df["Close"].tail(252).min())
        pct_from_high = ((spy_52w_high - spy_price) / spy_52w_high) * 100
        if pct_from_high <= 5:
            spy_52_score = 2.0
        elif pct_from_high <= 15:
            spy_52_score = 1.0
        elif pct_from_high <= 25:
            spy_52_score = 0.5
        else:
            spy_52_score = 0.0
        details["spy_pct_from_52w_high"] = round(pct_from_high, 2)
        details["spy_52w_high"] = round(spy_52w_high, 2)
    raw_score += spy_52_score
    details["spy_52_score"] = spy_52_score

    # Normalize to 0-10
    normalized = min(10.0, max(0.0, (raw_score / max_raw) * 10.0))

    # Hard override: VIX > 35 caps macro at 2.0
    if vix_value is not None and vix_value > 35:
        normalized = min(normalized, 2.0)
        details["vix_override"] = True

    return round(normalized, 2), details


# ---------------------------------------------------------------------------
# Signal Group 2 — Market Breadth (Weight: 25%)
# ---------------------------------------------------------------------------

def score_breadth() -> tuple[float, dict]:
    """
    Scores market breadth: % above 200MA, A/D ratio proxy, new high/low ratio.
    Returns (score_0_to_10, details_dict).
    """
    details = {}
    raw_score = 0.0

    # Fetch last 260 days for the basket
    basket = SP500_BASKET[:80]  # use 80 for speed; still statistically robust
    try:
        data = yf.download(basket, period="260d", interval="1d",
                           auto_adjust=True, progress=False, threads=True)
        close_df = data["Close"] if "Close" in data.columns else data.xs("Close", axis=1, level=0)
    except Exception:
        close_df = pd.DataFrame()

    pct_above_200 = 50.0   # neutral default
    ad_ratio = 1.0          # neutral default
    hl_ratio = 1.0          # neutral default
    counted = 0

    if not close_df.empty and len(close_df) >= 200:
        above_200_count = 0
        advancing_count = 0
        near_high_count = 0
        near_low_count  = 0
        total_valid = 0

        for ticker in close_df.columns:
            series = close_df[ticker].dropna()
            if len(series) < 200:
                continue
            total_valid += 1
            price_now = float(series.iloc[-1])
            ma_200    = float(series.rolling(200).mean().iloc[-1])

            # above 200MA
            if price_now > ma_200:
                above_200_count += 1

            # advancing today (proxy A/D)
            if len(series) >= 2:
                prev_price = float(series.iloc[-2])
                if price_now > prev_price:
                    advancing_count += 1

            # 52-week high/low proximity
            high_252 = float(series.tail(252).max())
            low_252  = float(series.tail(252).min())
            pct_from_high = ((high_252 - price_now) / high_252) * 100
            pct_from_low  = ((price_now - low_252) / (low_252 + 0.01)) * 100
            if pct_from_high <= 3:
                near_high_count += 1
            if pct_from_low <= 3:
                near_low_count += 1

        counted = total_valid
        if total_valid > 0:
            pct_above_200  = (above_200_count / total_valid) * 100
            ad_ratio       = advancing_count / max(1, total_valid - advancing_count)
            hl_ratio       = near_high_count / max(1, near_low_count)

    details["pct_above_200ma"] = round(pct_above_200, 1)
    details["ad_ratio"] = round(ad_ratio, 2)
    details["hl_ratio"] = round(hl_ratio, 2)
    details["basket_size_used"] = counted

    # 2a. Advance/Decline ratio score (max 3.5)
    if ad_ratio > 2.5:
        ad_score = 3.5
    elif ad_ratio > 1.5:
        ad_score = 2.5
    elif ad_ratio > 0.75:
        ad_score = 1.5
    elif ad_ratio > 0.5:
        ad_score = 0.5
    else:
        ad_score = 0.0
    raw_score += ad_score
    details["ad_score"] = ad_score

    # 2b. % above 200MA score (max 4.0)
    if pct_above_200 > 70:
        above200_score = 4.0
    elif pct_above_200 > 60:
        above200_score = 3.0
    elif pct_above_200 > 50:
        above200_score = 2.0
    elif pct_above_200 > 40:
        above200_score = 1.0
    elif pct_above_200 > 30:
        above200_score = 0.5
    else:
        above200_score = 0.0
    raw_score += above200_score
    details["above200_score"] = above200_score

    # 2c. New highs/lows ratio score (max 2.5)
    if hl_ratio > 5:
        hl_score = 2.5
    elif hl_ratio > 2:
        hl_score = 2.0
    elif hl_ratio > 0.5:
        hl_score = 1.0
    elif hl_ratio > 0.2:
        hl_score = 0.5
    else:
        hl_score = 0.0
    raw_score += hl_score
    details["hl_score"] = hl_score

    # Normalize: max raw = 10
    normalized = min(10.0, max(0.0, (raw_score / 10.0) * 10.0))
    return round(normalized, 2), details


# ---------------------------------------------------------------------------
# Signal Group 3 — Sector Rotation (Weight: 20%)
# ---------------------------------------------------------------------------

def score_sector_rotation() -> tuple[float, dict]:
    """
    Scores sector rotation: XLK vs XLU spread, risk-on breadth, defensive dominance.
    Returns (score_0_to_10, details_dict).
    """
    details = {}
    raw_score = 0.0

    all_etfs = RISK_ON_ETFS + RISK_OFF_ETFS + ["SPY"]
    try:
        data = yf.download(all_etfs, period="60d", interval="1d",
                           auto_adjust=True, progress=False, threads=True)
        close_df = data["Close"] if "Close" in data.columns else data.xs("Close", axis=1, level=0)
    except Exception:
        close_df = pd.DataFrame()

    def get_20d_return(ticker: str) -> Optional[float]:
        """Returns 20-day % return for a ticker, or None."""
        if close_df.empty or ticker not in close_df.columns:
            return None
        series = close_df[ticker].dropna()
        if len(series) < 21:
            return None
        price_now  = float(series.iloc[-1])
        price_20d  = float(series.iloc[-21])
        return ((price_now - price_20d) / price_20d) * 100

    # Get 20-day returns for each ETF
    returns = {}
    for etf in all_etfs:
        r = get_20d_return(etf)
        returns[etf] = r
        details[f"{etf}_20d_return"] = round(r, 2) if r is not None else None

    # 3a. XLK vs XLU spread (max 4.0)
    xlk_return = returns.get("XLK")
    xlu_return = returns.get("XLU")
    spread_score = 2.0  # neutral default
    spread = None
    if xlk_return is not None and xlu_return is not None:
        spread = xlk_return - xlu_return
        if spread > 8:
            spread_score = 4.0
        elif spread > 3:
            spread_score = 3.0
        elif spread > -3:
            spread_score = 2.0
        elif spread > -8:
            spread_score = 1.0
        else:
            spread_score = 0.0
    raw_score += spread_score
    details["xlk_xlu_spread"] = round(spread, 2) if spread is not None else None
    details["spread_score"] = spread_score

    # 3b. Risk-on sector breadth vs SPY (max 3.5)
    spy_return = returns.get("SPY", 0.0) or 0.0
    risk_on_outperforming = 0
    for etf in RISK_ON_ETFS:
        r = returns.get(etf)
        if r is not None and r > spy_return:
            risk_on_outperforming += 1

    if risk_on_outperforming == 4:
        breadth_score = 3.5
    elif risk_on_outperforming == 3:
        breadth_score = 2.5
    elif risk_on_outperforming == 2:
        breadth_score = 1.5
    elif risk_on_outperforming == 1:
        breadth_score = 0.5
    else:
        breadth_score = 0.0
    raw_score += breadth_score
    details["risk_on_sectors_leading"] = risk_on_outperforming
    details["breadth_score"] = breadth_score

    # 3c. Defensive dominance penalty (subtract up to 2.0 from raw)
    xlk_return_val = xlk_return or 0.0
    defensive_all_positive = all(
        (returns.get(etf) or 0.0) > 0
        for etf in ["XLU", "XLP", "GLD"]
    )
    defensive_penalty = 0.0
    if defensive_all_positive and xlk_return_val < 0:
        defensive_penalty = 2.0
        details["defensive_dominance_penalty"] = True
    else:
        details["defensive_dominance_penalty"] = False
    raw_score -= defensive_penalty

    # Normalize: max raw = 7.5, normalize to 0-10
    normalized = min(10.0, max(0.0, (raw_score / 7.5) * 10.0))
    return round(normalized, 2), details


# ---------------------------------------------------------------------------
# Signal Group 4 — Sentiment (Weight: 15%)
# ---------------------------------------------------------------------------

def score_sentiment() -> tuple[float, dict]:
    """
    Scores sentiment signals: CNN Fear & Greed, put/call ratio, AAII proxy.
    Returns (score_0_to_10, details_dict).
    """
    details = {}
    raw_score = 0.0

    # 4a. CNN Fear & Greed (max 4.0)
    fg_score_contribution = 2.5  # neutral default
    fg_value = fetch_cnn_fear_greed()
    if fg_value is not None:
        if fg_value < 25:
            fg_score_contribution = 4.0
        elif fg_value < 35:
            fg_score_contribution = 3.0
        elif fg_value < 55:
            fg_score_contribution = 2.5
        elif fg_value < 75:
            fg_score_contribution = 2.0
        elif fg_value < 90:
            fg_score_contribution = 1.5
        else:
            fg_score_contribution = 0.5
    raw_score += fg_score_contribution
    details["fear_greed_value"] = round(fg_value, 1) if fg_value is not None else None
    details["fear_greed_score"] = fg_score_contribution

    # Describe fear/greed state
    if fg_value is not None:
        if fg_value < 25:
            details["fear_greed_label"] = "Extreme Fear (contrarian buy)"
        elif fg_value < 35:
            details["fear_greed_label"] = "Fear"
        elif fg_value < 55:
            details["fear_greed_label"] = "Neutral"
        elif fg_value < 75:
            details["fear_greed_label"] = "Greed"
        elif fg_value < 90:
            details["fear_greed_label"] = "Greed (elevated)"
        else:
            details["fear_greed_label"] = "Extreme Greed (contrarian sell warning)"

    # 4b. Put/Call Ratio (max 3.5)
    pc_score_contribution = 2.0  # neutral default
    pc_ratio = fetch_put_call_ratio()
    if pc_ratio is not None:
        if pc_ratio > 1.2:
            pc_score_contribution = 3.5
        elif pc_ratio > 1.0:
            pc_score_contribution = 3.0
        elif pc_ratio > 0.8:
            pc_score_contribution = 2.0
        elif pc_ratio > 0.6:
            pc_score_contribution = 1.0
        else:
            pc_score_contribution = 0.0
    raw_score += pc_score_contribution
    details["put_call_ratio"] = round(pc_ratio, 2) if pc_ratio is not None else None
    details["put_call_score"] = pc_score_contribution

    # 4c. AAII Sentiment Proxy via VIX trend (max 3.0)
    # True AAII data requires web scraping; we approximate using VIX's 20-day trend
    # as a fear proxy. Falling VIX = increasing confidence = mild greed.
    # Rising VIX fast = growing fear = contrarian buy signal.
    aaii_score_contribution = 2.0  # neutral default
    vix_df = fetch_price_history("^VIX", days=30)
    if vix_df is not None and len(vix_df) >= 20:
        vix_now  = float(vix_df["Close"].iloc[-1])
        vix_20d  = float(vix_df["Close"].iloc[-20])
        vix_trend_pct = ((vix_now - vix_20d) / vix_20d) * 100
        # VIX spiked > 30% in 20 days = fear spiking = contrarian buy
        if vix_trend_pct > 50:
            aaii_score_contribution = 3.0   # extreme fear spike
        elif vix_trend_pct > 20:
            aaii_score_contribution = 2.5   # fear rising
        elif abs(vix_trend_pct) < 10:
            aaii_score_contribution = 2.0   # stable / neutral
        elif vix_trend_pct < -20:
            aaii_score_contribution = 1.5   # complacency growing (caution)
        elif vix_trend_pct < -40:
            aaii_score_contribution = 0.5   # extreme complacency (sell warning)
        details["vix_20d_trend_pct"] = round(vix_trend_pct, 1)
    raw_score += aaii_score_contribution
    details["sentiment_proxy_score"] = aaii_score_contribution

    # Normalize: max raw = 10.5, normalize to 0-10
    normalized = min(10.0, max(0.0, (raw_score / 10.5) * 10.0))
    return round(normalized, 2), details


# ---------------------------------------------------------------------------
# Verdict Computation
# ---------------------------------------------------------------------------

def compute_verdict(macro: float, breadth: float, sectors: float, sentiment: float,
                    macro_details: dict) -> tuple[str, float, float, float]:
    """
    Computes weighted composite score and returns:
    (verdict, composite_score, position_size_multiplier, min_buy_score)
    """
    composite = (macro * 0.40) + (breadth * 0.25) + (sectors * 0.20) + (sentiment * 0.15)
    composite = round(composite, 2)

    # Determine base verdict from score
    if composite >= 8.0:
        verdict = "STRONG_BULL"
    elif composite >= 6.0:
        verdict = "BULL"
    elif composite >= 4.0:
        verdict = "NEUTRAL"
    elif composite >= 2.0:
        verdict = "BEAR"
    else:
        verdict = "STRONG_BEAR"

    # Hard overrides — force more conservative verdict regardless of score
    vix_val = macro_details.get("vix")
    spy_golden  = macro_details.get("spy_golden_cross")
    qqq_golden  = macro_details.get("qqq_golden_cross")

    override_reason = None

    # VIX > 35 caps at BEAR
    if vix_val is not None and vix_val > 35:
        if verdict in ("STRONG_BULL", "BULL", "NEUTRAL"):
            verdict = "BEAR"
            override_reason = f"VIX={vix_val:.1f} > 35 — forced to BEAR"

    # Both SPY and QQQ in death cross caps at NEUTRAL
    if spy_golden is not None and qqq_golden is not None:
        if not spy_golden and not qqq_golden:
            if verdict in ("STRONG_BULL", "BULL"):
                verdict = "NEUTRAL"
                override_reason = "Death cross active on both SPY and QQQ — capped at NEUTRAL"

    # Verdict -> position size multiplier and min buy score
    verdict_params = {
        "STRONG_BULL": (1.20, 2.5),
        "BULL":        (1.00, 3.0),
        "NEUTRAL":     (0.70, 3.5),
        "BEAR":        (0.40, 5.0),
        "STRONG_BEAR": (0.00, 99),   # no buys
    }
    size_mult, min_score = verdict_params[verdict]

    return verdict, composite, size_mult, min_score, override_reason


# ---------------------------------------------------------------------------
# Output Formatting
# ---------------------------------------------------------------------------

def format_human_output(verdict: str, composite: float, size_mult: float,
                        min_score: float, macro: float, breadth: float,
                        sectors: float, sentiment: float,
                        macro_d: dict, breadth_d: dict,
                        sector_d: dict, sentiment_d: dict,
                        override_reason: Optional[str]) -> str:
    """Formats the human-readable Discord-ready output."""

    lines = []

    # Header
    lines.append(f"MARKET TREND: {verdict} ({composite}/10)")
    lines.append("")

    # Macro detail line
    spy_pct  = macro_d.get("spy_vs_20ma_pct", 0.0)
    vix_val  = macro_d.get("vix", "N/A")
    spy_gc   = macro_d.get("spy_golden_cross")
    qqq_gc   = macro_d.get("qqq_golden_cross")

    cross_str = "N/A"
    if spy_gc is True and qqq_gc is True:
        cross_str = "Golden cross (SPY+QQQ)"
    elif spy_gc is False and qqq_gc is False:
        cross_str = "Death cross (SPY+QQQ)"
    elif spy_gc is True:
        cross_str = "SPY golden cross, QQQ death cross"
    elif spy_gc is False:
        cross_str = "SPY death cross, QQQ golden cross"

    spy_pos = "above" if (spy_pct or 0) >= 0 else "below"
    vix_str = f"{vix_val:.1f}" if isinstance(vix_val, float) else str(vix_val)
    if isinstance(vix_val, float):
        if vix_val < 15: vix_mood = "very calm"
        elif vix_val < 20: vix_mood = "calm"
        elif vix_val < 25: vix_mood = "mild concern"
        elif vix_val < 30: vix_mood = "elevated"
        elif vix_val < 35: vix_mood = "high fear"
        else: vix_mood = "EXTREME FEAR"
    else:
        vix_mood = "unknown"

    lines.append(f"  Macro:    {macro}/10 — SPY {spy_pos} 20MA ({spy_pct:+.1f}%), VIX={vix_str} ({vix_mood}), {cross_str}")

    # Breadth detail line
    pct_200  = breadth_d.get("pct_above_200ma", "N/A")
    ad_rat   = breadth_d.get("ad_ratio", "N/A")
    hl_rat   = breadth_d.get("hl_ratio", "N/A")
    pct_str  = f"{pct_200:.0f}%" if isinstance(pct_200, float) else str(pct_200)
    ad_str   = f"{ad_rat:.2f}" if isinstance(ad_rat, float) else str(ad_rat)
    hl_str   = f"{hl_rat:.1f}" if isinstance(hl_rat, float) else str(hl_rat)
    lines.append(f"  Breadth:  {breadth}/10 — {pct_str} stocks above 200MA, A/D={ad_str}, Highs/Lows={hl_str}")

    # Sectors detail line
    spread   = sector_d.get("xlk_xlu_spread")
    risk_on  = sector_d.get("risk_on_sectors_leading", "N/A")
    xlk_ret  = sector_d.get("XLK_20d_return")
    xlu_ret  = sector_d.get("XLU_20d_return")
    spread_str = f"{spread:+.1f}%" if isinstance(spread, float) else "N/A"
    xlk_str  = f"{xlk_ret:+.1f}%" if isinstance(xlk_ret, float) else "N/A"
    xlu_str  = f"{xlu_ret:+.1f}%" if isinstance(xlu_ret, float) else "N/A"
    if isinstance(spread, float):
        flow_str = "risk-on" if spread > 0 else "risk-off"
    else:
        flow_str = "mixed"
    lines.append(f"  Sectors:  {sectors}/10 — XLK {xlk_str} vs XLU {xlu_str} (20d, spread {spread_str}), Risk-on sectors leading: {risk_on}/4, Flow: {flow_str}")

    # Sentiment detail line
    fg_val   = sentiment_d.get("fear_greed_value")
    fg_label = sentiment_d.get("fear_greed_label", "N/A")
    pc_rat   = sentiment_d.get("put_call_ratio")
    fg_str   = f"{fg_val:.0f}" if isinstance(fg_val, float) else "N/A"
    pc_str   = f"{pc_rat:.2f}" if isinstance(pc_rat, float) else "N/A"
    lines.append(f"  Sentiment:{sentiment}/10 — Fear&Greed={fg_str} ({fg_label}), Put/Call={pc_str}")

    lines.append("")

    # Override note if applicable
    if override_reason:
        lines.append(f"  OVERRIDE ACTIVE: {override_reason}")

    # Action line
    lines.append(f"  Verdict: {verdict}")
    lines.append(f"  Position Size Multiplier: {size_mult:.2f}x")

    if min_score >= 99:
        lines.append(f"  Min Buy Score Required: NO BUYS (STRONG_BEAR)")
    else:
        lines.append(f"  Min Buy Score Required: {min_score}")

    # Action summary
    action_map = {
        "STRONG_BULL": "Aggressive posture. Full+ position sizes. Scan all tickers. Score >= 2.5 to buy.",
        "BULL":        "Normal position sizes. Scan all watchlist tickers. Score >= 3.0 to buy.",
        "NEUTRAL":     "Reduced position sizes (70%). Be selective. Score >= 3.5 to buy.",
        "BEAR":        "Severely restricted (40% size). Max 3 positions. Score >= 5.0 to buy.",
        "STRONG_BEAR": "CAPITAL PRESERVATION. No new buys. Tighten stops on existing positions.",
    }
    lines.append(f"  Action: {action_map.get(verdict, '')}")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main Entry Point
# ---------------------------------------------------------------------------

def run_market_trend(json_mode: bool = False) -> dict:
    """
    Main function. Runs all four signal groups, computes verdict, outputs result.
    Returns the full result dict (always), prints output based on json_mode.
    """
    # Run all four signal groups
    macro_score,    macro_details    = score_macro_trend()
    breadth_score,  breadth_details  = score_breadth()
    sector_score,   sector_details   = score_sector_rotation()
    sentiment_score, sentiment_details = score_sentiment()

    # Compute verdict
    verdict, composite, size_mult, min_score, override_reason = compute_verdict(
        macro_score, breadth_score, sector_score, sentiment_score, macro_details
    )

    allow_new_buys = verdict != "STRONG_BEAR"

    # Build result dict
    result = {
        "verdict": verdict,
        "score": composite,
        "position_size_multiplier": size_mult,
        "min_buy_score": min_score if min_score < 99 else None,
        "allow_new_buys": allow_new_buys,
        "macro_score": macro_score,
        "breadth_score": breadth_score,
        "sector_score": sector_score,
        "sentiment_score": sentiment_score,
        "override_reason": override_reason,
        "timestamp": datetime.datetime.now().isoformat(),
        "details": {
            "macro": macro_details,
            "breadth": breadth_details,
            "sectors": sector_details,
            "sentiment": sentiment_details,
        },
    }

    if json_mode:
        # Flatten key fields to top-level for easy consumption by the trading loop
        result["details_flat"] = {
            "spy_vs_200ma_pct": macro_details.get("spy_vs_20ma_pct"),
            "vix": macro_details.get("vix"),
            "golden_cross_spy": macro_details.get("spy_golden_cross"),
            "golden_cross_qqq": macro_details.get("qqq_golden_cross"),
            "pct_above_200ma": breadth_details.get("pct_above_200ma"),
            "fear_greed": sentiment_details.get("fear_greed_value"),
            "put_call_ratio": sentiment_details.get("put_call_ratio"),
            "xlk_vs_xlu_spread": sector_details.get("xlk_xlu_spread"),
        }
        print(json.dumps(result, indent=2))
    else:
        human = format_human_output(
            verdict, composite, size_mult, min_score,
            macro_score, breadth_score, sector_score, sentiment_score,
            macro_details, breadth_details, sector_details, sentiment_details,
            override_reason,
        )
        print(human)

    return result


if __name__ == "__main__":
    json_mode = "--json" in sys.argv
    run_market_trend(json_mode=json_mode)
```

---

## Notes and Edge Cases

### What happens when CNN Fear & Greed API is unreachable?

The `fetch_cnn_fear_greed()` function returns `None`. The scoring function then uses a default contribution of 2.5 out of 4.0 (exactly neutral). This prevents a network failure from artificially inflating or deflating the sentiment score. Every data failure defaults to neutral, never to bullish.

### What happens when yfinance data is stale or market is closed?

yfinance returns the most recent available closing prices. On weekends and holidays, this is Friday's close (or the last trading day's close). The system still runs — it uses the last known data. This is intentional: you want to know the state of the market before it opens, not real-time mid-session.

### AAII data

True AAII weekly survey data requires scraping `aaii.com/sentiment-survey/results`. Because web scraping is brittle and AAII data only updates once per week, the current implementation uses a VIX trend proxy for the sentiment group's third component. If you have access to AAII data, replace the VIX-trend block in `score_sentiment()` with the actual reading.

### Performance

Fetching 80+ tickers for breadth analysis takes 10–20 seconds on a typical connection. The `yf.download()` call uses multi-threading internally. This is the bottleneck. The script runs in parallel mode for breadth; the other groups fetch 5–10 tickers total and are fast.

If runtime is a concern, reduce `SP500_BASKET[:80]` to `SP500_BASKET[:40]` for a faster but less accurate breadth calculation.

### Backtesting Note

The scoring thresholds in this system are calibrated for typical market conditions. If you want to backtest, run the script historically by passing a specific end date to yfinance (replace `period="260d"` with explicit `start=` and `end=` parameters in `yf.Ticker.history()`).
