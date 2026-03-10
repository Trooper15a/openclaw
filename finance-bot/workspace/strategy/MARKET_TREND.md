# Market Trend Prediction Framework — FinClaw Trading Bot

## Purpose

Before scanning a single stock, the bot must understand the macro environment it is operating in. A great stock setup in a collapsing market is still a losing trade. This document defines the comprehensive market trend prediction system that runs as Step 0 of every trading session — before economic calendar, before halal screening, before everything.

The output of this system is a single **Market Verdict** (STRONG_BULL / BULL / NEUTRAL / BEAR / STRONG_BEAR) and a **position_size_multiplier** that all subsequent steps use. If the market is in STRONG_BEAR, no new buys happen at all, full stop.

---

## Signal Architecture

The market verdict is computed from four signal groups, each scored 0–10, then weighted into a final composite score (0–10).

| Signal Group         | Weight | What It Measures                                      |
|----------------------|--------|-------------------------------------------------------|
| Macro Trend          | 40%    | Index MAs, VIX, 52-week positioning                  |
| Market Breadth       | 25%    | How many stocks are participating in any move         |
| Sector Rotation      | 20%    | Where institutional money is flowing                  |
| Sentiment            | 15%    | Investor fear/greed extremes (contrarian signals)     |

**Final Score = (Macro × 0.40) + (Breadth × 0.25) + (Sectors × 0.20) + (Sentiment × 0.15)**

---

## Group 1 — Macro Trend Signals (Weight: 40%)

These signals read the primary trend of the broad market using price and volatility data. All data is free via yfinance (SPY, QQQ, ^VIX).

### 1a. Golden Cross / Death Cross (SPY and QQQ)

The relationship between the 50-day and 200-day moving averages is the single most reliable long-term trend indicator. Institutional money respects these levels.

| Condition                                      | Signal    | Score Contribution |
|------------------------------------------------|-----------|--------------------|
| Both SPY and QQQ: 50MA > 200MA (golden cross)  | Bullish   | +3.0               |
| One of two in golden cross                     | Neutral+  | +1.5               |
| Both SPY and QQQ: 50MA < 200MA (death cross)   | Bearish   | +0.0               |
| One of two in death cross                      | Neutral-  | +0.5               |

**Calculation**: Pull 252 days of price history for SPY and QQQ. Compute rolling 50-day and 200-day simple moving averages. Compare the most recent values.

### 1b. SPY vs 20-Day MA (Short-Term Trend)

The 20-day MA is the short-term trend filter. It separates a healthy pullback from the start of a breakdown.

| Condition                            | Signal   | Score Contribution |
|--------------------------------------|----------|--------------------|
| SPY price > 20-day MA by > 2%        | Bullish  | +2.0               |
| SPY price > 20-day MA (within 2%)    | Neutral+ | +1.0               |
| SPY price < 20-day MA (within 2%)    | Neutral- | +0.5               |
| SPY price < 20-day MA by > 2%        | Bearish  | +0.0               |

### 1c. VIX Level — Fear Gauge

VIX measures implied volatility. It moves inversely to the market. Extreme fear (very high VIX) is a contrarian bullish signal. Complacency (very low VIX) can precede tops.

| VIX Level    | Market State         | Score Contribution |
|--------------|----------------------|--------------------|
| < 15         | Low fear, complacent | +3.0               |
| 15–20        | Calm, healthy        | +2.5               |
| 20–25        | Mild concern         | +2.0               |
| 25–30        | Elevated fear        | +1.0               |
| 30–35        | High fear            | +0.5               |
| > 35         | Extreme fear / crash | +0.0               |

Note: VIX > 35 is an automatic flag. Even if other signals look acceptable, BEAR or STRONG_BEAR verdicts are forced when VIX exceeds 35.

### 1d. SPY 52-Week High/Low Proximity

Where SPY is trading relative to its annual range reveals trend strength.

| Condition                                      | Signal   | Score Contribution |
|------------------------------------------------|-----------|--------------------|
| SPY within 5% of 52-week high                 | Bullish  | +2.0               |
| SPY 5%–15% below 52-week high                 | Neutral  | +1.0               |
| SPY 15%–25% below 52-week high                | Bearish  | +0.5               |
| SPY > 25% below 52-week high (bear market)    | Crash    | +0.0               |

**Macro Group Score Calculation**: Sum contributions from 1a + 1b + 1c + 1d. Maximum raw sum = 10. Normalize to 0–10. (If raw sum already maxes at 10, no normalization needed.)

---

## Group 2 — Market Breadth Signals (Weight: 25%)

Price action in SPY alone can be misleading. Breadth tells you whether the move is broadly supported or narrowly driven by a handful of mega-caps. Narrow rallies collapse; broad rallies persist.

### 2a. Advance/Decline Ratio

Measures whether more stocks are rising than falling on a given day.

| A/D Ratio            | Signal   | Score Contribution |
|----------------------|----------|--------------------|
| > 2.5 (2.5x advancers vs decliners) | Strongly bullish | +3.5 |
| 1.5–2.5              | Bullish  | +2.5               |
| 0.75–1.5             | Neutral  | +1.5               |
| 0.5–0.75             | Bearish  | +0.5               |
| < 0.5                | Strongly bearish | +0.0     |

**Data source**: Use yfinance to proxy this. Pull a basket of 50+ major S&P 500 tickers for the day and compute what % are up vs down. Alternatively, use ^NYAD (NYSE Advance/Decline) if available via yfinance.

### 2b. % of S&P 500 Stocks Above Their 200-Day MA

This is the gold standard breadth indicator. A healthy market has most of its members in uptrends.

| % Above 200MA | Signal           | Score Contribution |
|---------------|------------------|--------------------|
| > 70%         | Strongly bullish | +4.0               |
| 60%–70%       | Bullish          | +3.0               |
| 50%–60%       | Neutral+         | +2.0               |
| 40%–50%       | Neutral-         | +1.0               |
| 30%–40%       | Bearish          | +0.5               |
| < 30%         | Strongly bearish | +0.0               |

**Data source**: Pull a representative basket of 100 S&P 500 tickers via yfinance. For each, compute 200-day MA. Count how many have price > 200MA. This is the best free approximation of the true indicator.

### 2c. New 52-Week Highs vs Lows Ratio

When new highs dominate new lows, the market has internal strength. When lows dominate highs, it's a distribution warning even if the index looks okay.

| Highs/Lows Ratio | Signal           | Score Contribution |
|------------------|------------------|--------------------|
| > 5 (highs >> lows) | Strongly bullish | +2.5          |
| 2–5              | Bullish          | +2.0               |
| 0.5–2            | Neutral          | +1.0               |
| 0.2–0.5          | Bearish          | +0.5               |
| < 0.2 (lows >> highs) | Strongly bearish | +0.0        |

**Data source**: Approximate via yfinance. Pull 150+ major tickers. Count those within 2% of their 52-week high vs those within 2% of their 52-week low. Ratio = highs count / (lows count + 1).

**Breadth Group Score Calculation**: Sum 2a + 2b + 2c raw contributions, normalize to 0–10 scale.

---

## Group 3 — Sector Rotation Signals (Weight: 20%)

Institutional money rotates between sectors based on risk appetite. Watching this rotation is like watching the smart money vote in real time.

### Risk-On vs Risk-Off Sector Definitions

**Risk-On sectors (bullish signal when they lead):**
- XLK — Technology (highest beta, first to rise in bull markets)
- XLY — Consumer Discretionary (people spend when confident)
- XLB — Materials (growth-dependent)
- XLI — Industrials (economic expansion proxy)

**Risk-Off sectors (bearish signal when they lead):**
- XLU — Utilities (defensive, dividend-heavy, inversely correlated with rates)
- XLP — Consumer Staples (people eat whether market is up or down)
- GLD — Gold (flight to safety in uncertainty)
- IEF — 7–10 Year Treasuries (bond buying = equity selling)

### 3a. XLK vs XLU 20-Day Performance Spread

This is the clearest single measure of risk appetite. When tech is outperforming utilities, institutions are risk-on.

| XLK 20-day return minus XLU 20-day return | Signal           | Score Contribution |
|-------------------------------------------|------------------|--------------------|
| > +8%                                     | Strongly risk-on | +4.0               |
| +3% to +8%                               | Risk-on          | +3.0               |
| -3% to +3%                               | Neutral          | +2.0               |
| -8% to -3%                               | Risk-off         | +1.0               |
| < -8%                                    | Strongly risk-off| +0.0               |

### 3b. Breadth of Risk-On Sector Leadership

Count how many risk-on sectors (XLK, XLY, XLB, XLI) are outperforming SPY over the last 20 days.

| Risk-On Sectors Outperforming SPY | Signal   | Score Contribution |
|-----------------------------------|----------|--------------------|
| 4 of 4                            | Bullish  | +3.5               |
| 3 of 4                            | Neutral+ | +2.5               |
| 2 of 4                            | Neutral  | +1.5               |
| 1 of 4                            | Neutral- | +0.5               |
| 0 of 4                            | Bearish  | +0.0               |

### 3c. Defensive Sector Dominance Check

If XLU, XLP, or GLD are all positive while XLK is negative — that is a hard risk-off signal.

| Condition                                          | Adjustment           |
|----------------------------------------------------|----------------------|
| XLU + XLP + GLD all > 0% (20-day) AND XLK < 0%   | -2 penalty to group score |
| XLU + XLP + GLD all > 0% (20-day), XLK positive  | No change            |
| Defensive sectors mixed, tech leading              | No change            |

**Sector Group Score Calculation**: (3a + 3b contributions) with 3c penalty applied. Normalize to 0–10. Cap at 10, floor at 0.

---

## Group 4 — Sentiment Signals (Weight: 15%)

Sentiment indicators are contrarian. Extreme fear is historically a buy signal. Extreme greed is a sell warning. The key word is "extreme" — mild fear or mild greed tells you nothing actionable.

### 4a. CNN Fear & Greed Index

**Free API endpoint**: `https://production.dataviz.cnn.io/index/fearandgreed/graphdata`

The index combines 7 sub-indicators: stock price momentum, stock price strength, stock price breadth, put/call options ratio, junk bond demand, market volatility, and safe-haven demand. It outputs a 0–100 score.

| Fear & Greed Score | Market State          | Score Contribution |
|--------------------|----------------------|--------------------|
| 0–25               | Extreme Fear         | +4.0 (contrarian buy) |
| 25–35              | Fear                 | +3.0               |
| 35–55              | Neutral              | +2.5               |
| 55–75              | Greed                | +2.0               |
| 75–90              | Greed (elevated)     | +1.5               |
| 90–100             | Extreme Greed        | +0.5 (contrarian sell warning) |

Note: Extreme fear and extreme greed are BOTH warning signals — extreme fear is a near-term bottom signal but does not mean enter immediately, and extreme greed is a distribution risk warning. The scoring reflects that both extremes are more dangerous for new entries than the neutral zone.

### 4b. Put/Call Ratio (CBOE)

A high put/call ratio means investors are buying lots of downside protection — this is a fear signal that often precedes a bottom. A very low ratio signals complacency.

**Data**: The put/call ratio can be fetched via yfinance using ticker `^PCALL` or scraped from CBOE. Use a 5-day average to smooth daily noise.

| 5-Day Avg Put/Call Ratio | Signal               | Score Contribution |
|--------------------------|----------------------|--------------------|
| > 1.2                    | Extreme fear (contrarian bullish) | +3.5 |
| 1.0–1.2                  | Fear (mildly bullish) | +3.0             |
| 0.8–1.0                  | Neutral              | +2.0               |
| 0.6–0.8                  | Complacency          | +1.0               |
| < 0.6                    | Extreme complacency (sell warning) | +0.0 |

### 4c. AAII Investor Sentiment (Weekly)

The American Association of Individual Investors publishes a weekly survey of retail investor sentiment. When retail investors are overwhelmingly bearish (bears > 50%), the market has historically produced above-average returns over the next 6–12 months. Retail investors are the last to buy at tops and the last to sell at bottoms.

**Data**: AAII publishes weekly data at aaii.com. This requires either scraping or manual input on a weekly basis. The bot should cache the most recent weekly reading.

| AAII Bull/Bear Spread (Bulls% minus Bears%)    | Signal               | Score Contribution |
|------------------------------------------------|----------------------|--------------------|
| Bears > 50% (spread < -20)                    | Extreme fear (strong contrarian buy) | +3.0 |
| Bears > Bulls (spread -20 to 0)               | Fear (mild contrarian buy) | +2.5     |
| Roughly equal (spread -5 to +5)               | Neutral              | +2.0               |
| Bulls > Bears (spread 0 to +20)               | Mild optimism        | +1.5               |
| Bulls > 55% (spread > +25)                    | Excessive optimism (contrarian sell risk) | +0.5 |

**Sentiment Group Score Calculation**: Sum 4a + 4b + 4c. Normalize to 0–10.

---

## Composite Score Calculation

```
Final Score = (macro_score × 0.40) + (breadth_score × 0.25) + (sector_score × 0.20) + (sentiment_score × 0.15)
```

All group scores are already normalized to 0–10 before weighting. The final score is therefore also on a 0–10 scale.

---

## Market Verdict System

### Verdict Table

| Verdict      | Score Range | Description                                              |
|--------------|-------------|----------------------------------------------------------|
| STRONG_BULL  | 8.0–10.0    | All systems green. Maximum participation.                |
| BULL         | 6.0–8.0     | Healthy market. Normal rules apply.                      |
| NEUTRAL      | 4.0–6.0     | Mixed signals. Reduce exposure, be more selective.       |
| BEAR         | 2.0–4.0     | Downtrend in control. Minimal new exposure.              |
| STRONG_BEAR  | 0.0–2.0     | Capital preservation mode. No new buys.                  |

### Override Rules (Hard Overrides — Trigger Regardless of Score)

These conditions force a more conservative verdict even if the composite score would suggest otherwise:

1. **VIX > 35**: Verdict cannot be better than BEAR, regardless of other signals.
2. **SPY below 200-day MA AND below 50-day MA**: Verdict cannot be better than NEUTRAL.
3. **Death cross active on both SPY and QQQ**: Verdict cannot be better than NEUTRAL.
4. **CNN Fear & Greed < 15 (extreme fear)**: Log as high-alert. Score can still be used but flag for Discord.
5. **All four defensive sectors (XLU, XLP, GLD, IEF) outperforming SPY over 20 days**: Verdict cannot be better than BEAR.

### Trading Instructions by Verdict

#### STRONG_BULL (8.0–10.0)
- Full position sizes. Up to 120% of normal sizing on highest conviction trades.
- Momentum requirement relaxed: score ≥ 2.5 triggers a buy (normal minimum is 3).
- Scan entire watchlist aggressively.
- Can hold up to maximum number of simultaneous positions.
- Log: "MARKET: STRONG_BULL — all signals green. Aggressive posture active."

#### BULL (6.0–8.0)
- Normal position sizes (1× multiplier).
- Normal buy threshold: score ≥ 3.
- Normal watchlist scan.
- Log: "MARKET: BULL — healthy conditions. Normal rules apply."

#### NEUTRAL (4.0–6.0)
- Reduce position sizes to 70% of normal (multiplier = 0.70).
- Raise buy threshold: score ≥ 3.5 required (not 3).
- Skip marginal setups. Only take high-conviction trades.
- Do not open more than 5 simultaneous positions.
- Log: "MARKET: NEUTRAL — mixed signals. Selective approach active."

#### BEAR (2.0–4.0)
- Reduce position sizes to 40% of normal (multiplier = 0.40).
- Raise buy threshold significantly: score ≥ 5 required.
- Max 3 open positions simultaneously.
- Only defensive-sector halal stocks or the absolute highest conviction setups.
- Tighten stop losses on existing positions (consider -5% instead of -7%).
- Log: "MARKET: BEAR — downtrend conditions. Severely restricted buying."

#### STRONG_BEAR (0.0–2.0)
- No new buy positions. Period. Even score-10 individual stocks get skipped.
- Cash is the position.
- Only action: tighten stops on existing holdings, let them hit naturally.
- Do not average down on any existing position.
- Log: "MARKET: STRONG_BEAR — capital preservation mode. No new buys."
- Discord alert: "MARKET VERDICT: STRONG_BEAR. Bot is holding cash. No new positions until market conditions improve."

---

## Data Freshness and Caching

| Signal              | Update Frequency | Cache Duration |
|---------------------|-----------------|----------------|
| SPY/QQQ MA crossovers | Daily           | 24 hours       |
| VIX level           | Real-time       | 15 minutes     |
| Breadth (% above 200MA) | Daily        | 24 hours       |
| Advance/Decline     | Daily           | 24 hours       |
| Sector rotation     | Daily           | 24 hours       |
| CNN Fear & Greed    | Every 6 hours   | 6 hours        |
| Put/Call ratio      | Daily           | 24 hours       |
| AAII sentiment      | Weekly (Friday) | 7 days         |

If any data fetch fails, that signal group's score defaults to 5.0 (exactly neutral). Never default to a bullish score on a data failure. Log all failures to Discord.

---

## Integration With Other Systems

### Interaction with Economic Calendar

The economic calendar check (ECONOMIC_CALENDAR_RULES.md) applies a position_size_multiplier on top of the market trend multiplier. They stack multiplicatively:

```
final_position_size = normal_size × market_trend_multiplier × economic_calendar_multiplier
```

Example: NEUTRAL market (0.70) + CPI day CAUTION (0.50) = 0.35× normal size.

### Interaction with Earnings Tracker

A STRONG_BEAR verdict does not override the earnings check — earnings skips still apply even if the market recovers. Both filters run independently.

### Interaction with Individual Stock Scoring

The market verdict sets the minimum buy threshold:

| Verdict     | Min Score to Buy |
|-------------|-----------------|
| STRONG_BULL | 2.5             |
| BULL        | 3.0             |
| NEUTRAL     | 3.5             |
| BEAR        | 5.0             |
| STRONG_BEAR | No buys         |

---

## Output Format

Every run of the market trend check must produce output in this exact format for Discord and logging:

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

---

## Historical Context for Calibration

These are the approximate composite scores that would have been computed during key historical market phases (for reference when tuning):

| Period                        | Approx Score | Verdict     |
|-------------------------------|-------------|-------------|
| Bull run 2021 (Jan–Oct)       | 7.5–9.0     | BULL / STRONG_BULL |
| Correction Nov–Dec 2021       | 5.0–6.0     | NEUTRAL     |
| Bear market 2022 (full year)  | 1.5–3.5     | BEAR / STRONG_BEAR |
| Recovery 2023 (H1)            | 5.5–7.0     | NEUTRAL / BULL |
| Strong bull 2023–2024         | 7.0–8.5     | BULL / STRONG_BULL |
| Correction early 2025         | 3.5–5.5     | NEUTRAL / BEAR |

---

## Why This System Runs Before Everything Else

Individual stock analysis is micro. Market trend is macro. Macro always wins. A technically perfect stock setup — perfect RSI, perfect volume, perfect news — will still lose 50% of the time in a confirmed bear market because the entire market is in distribution. Selling pressure overwhelms individual stock merits.

Running market trend analysis first means the bot never has to fight the tape. In STRONG_BEAR, sitting in cash and earning nothing is enormously better than watching carefully selected positions bleed -7% stops one after another. In STRONG_BULL, relaxing the entry threshold slightly means capturing more of the broad-based moves that define bull markets.

The system does not predict the future. It reads the present accurately and positions accordingly.
