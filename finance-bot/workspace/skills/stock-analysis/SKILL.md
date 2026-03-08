---
name: stock-analysis
description: "Performs in-depth technical and fundamental stock analysis, generates buy/hold/sell signals, and scores stocks across multiple dimensions. Use when: (1) user asks 'should I buy X' or 'analyze TSLA', (2) computing technical indicators like RSI or MACD on a ticker, (3) reviewing earnings history, analyst consensus, or valuation multiples, (4) comparing a stock against its sector peers. NOT for: real-time price monitoring or recurring price alerts (use finance-monitor), actual trade execution."
metadata:
  {
    "openclaw":
      {
        "emoji": "📉",
        "requires": { "bins": ["python3"] },
      },
  }
---

# Stock Analysis

## When to Use

- User asks a direct question such as "Should I buy NVDA?" or "Give me a full analysis of TSLA"
- Computing and interpreting technical indicators: RSI, MACD, Bollinger Bands, moving averages
- Reviewing a company's fundamental profile: valuation multiples, earnings growth, analyst ratings
- Evaluating earnings surprise history to understand how a company reacts to quarterly reports
- Scoring a stock on a structured multi-dimension rubric and producing a BUY / HOLD / SELL signal
- Comparing a stock's strength relative to its sector or benchmark index
- Identifying technical support and resistance levels or common chart patterns

## When NOT to Use

- Live price alerts or watchlist monitoring — use the `finance-monitor` skill instead
- Executing trades — this skill produces analysis only; it has no brokerage integration

## Setup

Install the required Python packages once:

```bash
pip install yfinance pandas ta pytz
```

- `yfinance` — pulls price history and fundamental data from Yahoo Finance
- `pandas` — data manipulation for time-series price history
- `ta` — technical analysis library with 40+ indicators (RSI, MACD, Bollinger Bands, etc.)
- `pytz` — timezone handling (Python 3.8+ compatible)

## Analysis Dimensions

Each analysis scores the stock from 1 (worst) to 10 (best) across eight dimensions. Average the dimension scores to produce the overall score.

| # | Dimension | What to Measure |
|---|-----------|-----------------|
| 1 | **Price Momentum** | RSI (14-period): oversold <30 scores high, overbought >70 scores low; MACD histogram direction and signal crossover |
| 2 | **Volume Trend** | 20-day average volume vs. 90-day average; rising volume on up-days vs. down-days |
| 3 | **Fundamentals** | Forward P/E vs. sector median; Price-to-Book; trailing EPS growth YoY |
| 4 | **Earnings Surprise History** | Last 4 quarters of actual vs. estimate; consistent beats score high, misses score low |
| 5 | **Analyst Consensus** | `recommendationKey` from `ticker.info` (strongBuy → 10, buy → 8, hold → 5, sell → 2, strongSell → 1); number of analysts covering |
| 6 | **News Sentiment** | Qualitative review of recent headlines surfaced via `ticker.news`; positive catalysts vs. negative overhangs |
| 7 | **Sector Relative Strength** | Compare 3-month return of the ticker against its sector ETF (e.g. XLK for tech, XLF for financials) |
| 8 | **Technical Pattern** | Identify nearest support and resistance levels from 52-week high/low and recent pivot points; note whether price is trending above or below key moving averages (50-day, 200-day) |

## Key Commands

### Get RSI (14-period)

```python
import yfinance as yf
import ta

ticker = yf.Ticker("NVDA")
hist = ticker.history(period="3mo", auto_adjust=True)
# Fix: add .dropna() before .iloc[-1] to guard against empty series
rsi = ta.momentum.RSIIndicator(close=hist['Close'], window=14).rsi().dropna().iloc[-1]
print(f"RSI: {rsi:.2f}")
```

### Get MACD signal line

```python
import yfinance as yf
import ta

ticker = yf.Ticker("NVDA")
hist = ticker.history(period="6mo", auto_adjust=True)
# Fix: compute MACD once, add .dropna() before .iloc[-1]
macd_obj    = ta.trend.MACD(close=hist['Close'])
macd_signal = macd_obj.macd_signal().dropna().iloc[-1]
macd_line   = macd_obj.macd().dropna().iloc[-1]
print(f"MACD: {macd_line:.4f}  Signal: {macd_signal:.4f}  Histogram: {macd_line - macd_signal:.4f}")
```

### Fundamental data

```python
import yfinance as yf

# Fix: wrap .info in try/except — it makes a network call and can raise on bad symbols
try:
    info = yf.Ticker("NVDA").info
except Exception:
    info = {}

print("Forward P/E    :", info.get("forwardPE"))
print("Price-to-Book  :", info.get("priceToBook"))
print("Earnings Growth:", info.get("earningsGrowth"))
print("Analyst Rating :", info.get("recommendationKey"))
print("Target Mean    :", info.get("targetMeanPrice"))
print("Analyst Count  :", info.get("numberOfAnalystOpinions"))
```

### Full analysis script outline

```python
import yfinance as yf
import ta
from datetime import date

TICKER = "AAPL"
t = yf.Ticker(TICKER)
hist = t.history(period="1y", auto_adjust=True)

# Fix: wrap .info in try/except
try:
    info = t.info
except Exception:
    info = {}

# --- Dimension 1: Price Momentum ---
# Fix: use keyword args (window=, not positional); add .dropna() before .iloc[-1]
rsi      = ta.momentum.RSIIndicator(close=hist['Close'], window=14).rsi().dropna().iloc[-1]
macd_obj = ta.trend.MACD(close=hist['Close'])
macd_hist = (macd_obj.macd().dropna().iloc[-1] - macd_obj.macd_signal().dropna().iloc[-1])

# --- Dimension 3: Fundamentals ---
fwd_pe = info.get("forwardPE", None)
ptb    = info.get("priceToBook", None)
eg     = info.get("earningsGrowth", None)

# --- Dimension 5: Analyst Consensus ---
rec = info.get("recommendationKey", "none")

# --- Dimension 8: Technical Pattern ---
# Fix: add .dropna() before .iloc[-1] on rolling means and Close
ma50  = hist['Close'].rolling(50).mean().dropna().iloc[-1]
ma200 = hist['Close'].rolling(200).mean().dropna().iloc[-1]
price = hist['Close'].dropna().iloc[-1]

# Score each dimension 1-10 (implement your own logic per the rubric above)
# overall_score = mean(scores)
# signal = "BUY" if score >= 7 else "HOLD" if score >= 4 else "SELL"
```

## Output Format

Structure every analysis response using the following template:

```
STOCK ANALYSIS — {TICKER}  ({Company Name})
Date: {YYYY-MM-DD}

Overall Score : {score:.1f} / 10
Signal        : {BUY | HOLD | SELL}

Dimension Scores
  1. Price Momentum        : {x}/10  — RSI {rsi:.1f}, MACD {direction}
  2. Volume Trend          : {x}/10  — {description}
  3. Fundamentals          : {x}/10  — Fwd P/E {fwd_pe}, P/B {ptb}
  4. Earnings Surprises    : {x}/10  — {description}
  5. Analyst Consensus     : {x}/10  — {recommendationKey}, {n} analysts
  6. News Sentiment        : {x}/10  — {description}
  7. Sector Rel. Strength  : {x}/10  — {pct vs sector} over 3 months
  8. Technical Pattern     : {x}/10  — {support/resistance description}

Key Risks
  - {risk 1}
  - {risk 2}

Key Catalysts
  - {catalyst 1}
  - {catalyst 2}

---
DISCLAIMER: This is not financial advice. Past performance does not predict
future results. Always do your own research before making investment decisions.
```

Always include all eight dimension scores and at least one risk and one catalyst, even if the information is limited.

## Important Disclaimers

Every analysis output MUST end with the following disclaimer verbatim:

> This is not financial advice. Past performance does not predict future results. Always do your own research.

Never omit this disclaimer, regardless of how the user phrases their request. Do not soften or reword it. The finance bot is an analytical tool, not a licensed financial adviser.

## Currency — Canadian Dollars (CAD)

All price references, target prices, and valuation figures MUST be displayed in **Canadian dollars (C$)**.
For US-listed tickers, convert to CAD using the live `CADUSD=X` forex rate from Yahoo Finance.
TSX-listed tickers (`.TO` suffix) are already in CAD.

## Ethical Screening (Halal Filter)

Before running any analysis, check whether the ticker belongs to an excluded sector.
**Excluded sectors:** alcohol, arms/defense, drugs (recreational), gambling, tobacco/smoking, vice.

If the user requests analysis on an excluded ticker:
1. Politely decline the analysis
2. Explain the ticker falls under the user's excluded sectors
3. Suggest a halal-compliant alternative in the same industry if possible
