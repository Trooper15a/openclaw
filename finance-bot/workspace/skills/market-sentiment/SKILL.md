---
name: market-sentiment
description: "Gathers market news, sentiment from financial sources, crypto Fear & Greed index, and trending tickers. Use when: user asks 'what's the market mood', 'any news on TSLA', 'is sentiment bullish'. NOT for: real-time price alerts (use finance-monitor), fundamental analysis (use stock-analysis)."
metadata:
  {
    "openclaw":
      {
        "emoji": "📰",
        "requires": { "bins": ["python3", "curl"] },
      },
  }
---

# Market Sentiment

## When to Use

- User asks about the general market mood or whether the market is bullish or bearish
- User asks for recent news on a specific ticker (e.g., "any news on TSLA?")
- User wants sector sentiment before making a trade decision
- User asks about pre-earnings sentiment or analyst expectations
- User wants a morning briefing that includes market context
- User asks about crypto sentiment or the Fear & Greed index

## Free Data Sources

All sources below are free and require no API key unless noted.

### CoinGecko (crypto prices + market cap)

```
https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=cad&include_24hr_change=true
```

Returns current CAD price and 24-hour percent change for major cryptocurrencies. Supports hundreds of coins — use the CoinGecko coin ID (e.g., `bitcoin`, `ethereum`, `solana`).

### Alternative.me Fear & Greed Index

```
https://api.alternative.me/fng/?limit=1
```

Returns a score from 0 (Extreme Fear) to 100 (Extreme Greed) with a text label. Originally built for crypto but widely used as a general risk sentiment gauge. Use `?limit=7` to get the past week of scores for trend context.

### Yahoo Finance News (via yfinance)

```python
import yfinance as yf
ticker = yf.Ticker("AAPL")
news = ticker.news  # list of dicts with title, publisher, link, providerPublishTime
```

Returns recent news articles for any ticker. Each item includes `title`, `publisher`, and `providerPublishTime` (Unix timestamp).

### Reddit PRAW (optional — requires API key)

For r/wallstreetbets or r/investing sentiment, PRAW can be used to scan post titles and scores. Requires a Reddit API key set via environment variables (`REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`). Only use this source if the user has configured Reddit credentials.

## Curl Examples

### Fear & Greed Index — single value

```bash
# Fix: use single quotes around the -c string so no shell escaping is needed inside
curl -s "https://api.alternative.me/fng/?limit=1" | python3 -c '
import sys, json
d = json.load(sys.stdin)
entry = d["data"][0]
# Fix: entry["value"] is a string from the API — cast to int for display
score = int(entry["value"])
print(f"Fear & Greed: {entry[\"value_classification\"]} ({score}/100)")
'
```

Example output: `Fear & Greed: Greed (72/100)`

### Fear & Greed trend — past 7 days

```bash
# Fix: use single quotes around the -c string
curl -s "https://api.alternative.me/fng/?limit=7" | python3 -c '
import sys, json
from datetime import datetime
d = json.load(sys.stdin)
for entry in reversed(d["data"]):
    date = datetime.fromtimestamp(int(entry["timestamp"])).strftime("%Y-%m-%d")
    # Fix: cast value string to int
    score = int(entry["value"])
    print(f"{date}: {entry[\"value_classification\"]} ({score}/100)")
'
```

### CoinGecko — BTC and ETH price with 24h change

```bash
curl -s "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=cad&include_24hr_change=true"
```

Example output:
```json
{
  "bitcoin": {"cad": 112000, "cad_24h_change": 1.85},
  "ethereum": {"cad": 4400, "cad_24h_change": -0.72}
}
```

## Sentiment Output Format

Always present sentiment in this structured format:

```
MARKET SENTIMENT — 2026-03-06 09:00 UTC

Overall: NEUTRAL (leaning bullish)
Fear & Greed Index: Greed (72/100)

BULLISH SIGNALS
  - BTC up +1.85% in 24h, holding above C$110k support
  - NVDA options flow shows heavy call buying ahead of earnings
  - ISM Services beat expectations (54.1 vs 52.0 est.)

BEARISH SIGNALS
  - 10Y Treasury yield rising (+6bps), pressure on growth stocks
  - VIX elevated at 18.4 (above 20-day average of 16.1)
  - ETH underperforming BTC, altcoin weakness persisting

KEY HEADLINES (past 24h)
  1. "Fed signals two rate cuts in 2026, markets rally" — Reuters
  2. "TSLA cuts prices in Europe amid demand slowdown" — Bloomberg
  3. "Apple AI features delayed to iOS 21, sources say" — 9to5Mac
  4. "Bitcoin ETF sees $400M inflow, largest in 3 months" — CoinDesk
  5. "Oil drops 2% on surprise inventory build" — Reuters
```

Scoring guidance:
- **Bullish**: Fear & Greed > 60, major indices up >0.5%, positive news flow
- **Bearish**: Fear & Greed < 40, major indices down >0.5%, negative catalysts
- **Neutral**: Mixed signals, Fear & Greed 40–60, flat markets

## When to Include in Reports

- **Always** include a sentiment summary in morning briefings (first interaction of the day).
- **Always** include sentiment context when the user asks for trade recommendations or entry/exit timing.
- Include sector-specific sentiment when the user asks about a specific stock or crypto.
- Skip sentiment if the user is asking a purely operational question (e.g., "what's my portfolio value?") and has not asked for market context.

## Currency — Canadian Dollars (CAD)

All price references in sentiment output MUST use **Canadian dollars (C$)**.
Use `vs_currencies=cad` when calling CoinGecko. Convert USD figures to CAD using the `CADUSD=X` forex rate.

## Ethical Screening (Halal Filter)

Do NOT surface news or sentiment for excluded sectors: alcohol, arms/defense, drugs (recreational), gambling, tobacco/smoking, vice.
If a headline involves an excluded ticker, skip it. Do not include excluded-sector stocks in trending ticker lists.
