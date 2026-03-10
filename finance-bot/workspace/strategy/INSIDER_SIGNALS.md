# Insider Signals — Buy Scoring Integration

How SEC Form 4 insider purchase data plugs into the FinClaw autonomous buy scoring system.

---

## Why Insider Buys Matter

Corporate insiders (CEOs, CFOs, directors) must file SEC Form 4 within two business days of
any transaction in their company's stock. When an executive buys shares on the open market
with personal cash — not option exercises, not DRIP reinvestment, not stock grants — it is
one of the clearest forward-looking signals available to retail investors.

**The logic is simple:** insiders know the business better than anyone. They buy for one
reason — they expect the stock to go higher.

Academic research (Seyhun 1986, Lakonishok & Lee 2001, Cohen et al. 2012) consistently
shows that open-market insider purchases, especially by C-suite officers, produce statistically
significant positive abnormal returns over the following 3–12 months. CEO purchases > $500k
show the strongest predictive power.

---

## Signal Tiers and Score Contribution

| Tier | Criteria | Score Added | Notes |
|------|----------|-------------|-------|
| HIGH | C-suite (CEO/CFO/COO/President) open-market buy > $500k | +1 | Always include in Discord alert |
| HIGH | Any insider buy > $1M | +1 | Extremely rare; always flag |
| HIGH | 3+ executives buying in same 30-day window | +1 | Cluster buying is very bullish |
| MEDIUM | Any named executive or director buy $50k–$500k | +1 | Include in briefing if other signals present |
| MEDIUM | C-suite buy $25k–$50k | +1 | Lower threshold applies for CEO/CFO only |
| LOW | Any buy < $50k, or director-only buy | +0 | Log for reference; do not score |
| NONE | No open-market purchases in window | +0 | Neutral; do not penalise |
| SKIP | Crypto, ETF, or .TO ticker | +0 | Not applicable to SEC filings |

Insider signal contributes a maximum of **+1** to the total buy score, regardless of how
many insiders bought. The score is not additive across multiple buyers — it is a flag, not
a multiplier. One HIGH signal is enough to unlock the +1.

---

## Where It Fits in the Buy Scoring System

The full FinClaw buy score is built from up to 5 independent signals. A score of 3 or
higher is required before a trade can be executed (see AUTONOMOUS_TRADING.md).

### The 5 Buy Score Dimensions

```
Dimension 1 — Technical: RSI, moving averages, MACD
Dimension 2 — Volume:    Volume surge vs 20-day average
Dimension 3 — Momentum:  Price action, trend direction
Dimension 4 — Sentiment: News sentiment, social signal (Tavily search)
Dimension 5 — Insider:   SEC Form 4 open-market purchase (this skill)
```

Each dimension contributes 0 or +1. A score of 3/5 = execute. A score of 2/5 = watchlist.
A score of 1/5 = ignore.

### Insider Signal in the Autonomous Loop

The insider check runs **after** the initial technical/sentiment scoring (Step 3 of
AUTONOMOUS_TRADING.md), specifically for tickers that already score 1 or higher. Running
it for every ticker unconditionally would waste EDGAR API calls on stocks the bot will
never buy.

```
Step 3 — Technical + Sentiment Scoring (existing)
  → Produces candidates list with scores 0–4

Step 3b — Insider Check (NEW — insert here)
  For each candidate with score >= 1:
    result = insider_monitor.scan_ticker(ticker, days_back=30)

    if result["signal"] in ("HIGH", "MEDIUM"):
      candidate.score += 1
      candidate.reasoning += f" | Insider: {result['signal']} buy confirmed"
      if result["signal"] == "HIGH":
        log_discord_alert(f"INSIDER BUY ALERT — {ticker}: {result['summary']}")

    if result["signal"] == "LOW":
      candidate.reasoning += f" | Insider: small buy noted (no score)"

    if result["signal"] in ("NONE", "SKIP"):
      pass  # no change, no log

Step 4 — Earnings Safety Check (existing)
  → Remove any candidate with earnings within 48h

Step 5 — Execute candidates with score >= 3
```

---

## Insider Buy Patterns That Matter Most

### 1. CEO Open-Market Purchase > $500k

The single strongest individual signal. A CEO spending half a million dollars of personal
money says: "I am confident enough in this company's near-term direction to concentrate
personal wealth here." Score: HIGH.

### 2. Cluster Buying (Multiple Executives, Same Window)

When 3+ different executives buy in the same 30-day window, even if each purchase is
modest ($50k–$200k), the pattern is very bullish. The insiders have independently reached
the same conclusion. Score: HIGH (elevated from MEDIUM by the cluster rule).

### 3. First Purchase After a Long Absence

If an executive has not bought shares in 2+ years and suddenly makes an open-market
purchase, it deserves extra attention. This is harder to detect via EDGAR full-text search
alone — the autonomous loop does not currently track historical purchase frequency, but
it can be added if needed.

### 4. Purchase During Market Downturn

An insider buying during a broad market sell-off, while their stock is down 15–20%,
demonstrates especially high conviction. The autonomous trading loop should weight this
scenario more heavily. If the EDGAR filing date falls within a week of a significant
index drawdown (SPY down > 5% over 10 days), treat the signal as one tier higher.

---

## Signals That Look Like Insider Buys But Are Not

These patterns are filtered out by the insider-monitor skill. Understanding why matters.

### Option Exercises (transactionCode = M or A)

An executive "buying" shares by exercising stock options is not a market-conviction buy.
They already owned those options as compensation. The exercise price was set years ago.
This tells you nothing about their current view on the stock price.
**Filter: skip all transactions where transactionCode != "P" (Purchase).**

### 10b5-1 Plan Purchases

Some insider purchases are made under a pre-arranged 10b5-1 trading plan, which was set
up months or years in advance. These are less informative than discretionary buys because
the insider may have set up the plan under very different market conditions.

The EDGAR XML includes a `<transactionTimeliness>` field and sometimes a `<planFootnote>`
reference. A future enhancement to the script could de-weight or skip 10b5-1 purchases.
For now, they are included but noted.

### Dividend Reinvestment (DRIP)

DRIP purchases appear as "P" transactions at small, regular amounts. They are noise.
The $50k minimum threshold effectively filters most DRIP activity. A CFO reinvesting
a $1,200 dividend is not a signal.

### Same-Day Sale After Exercise

An executive exercises options and immediately sells the acquired shares (a "cashless
exercise"). Both legs appear in Form 4. The buy leg has transactionCode "M" (exercise)
and the sell leg has "S". The net cash effect is zero or positive for the insider.
**Filter: only transactionCode "P" (open-market purchase) is counted.**

---

## Currency Handling

SEC Form 4 filings are always in USD. FinClaw operates in CAD. For display purposes,
convert the USD purchase amount to CAD using the CADUSD=X rate from yfinance:

```python
import yfinance as yf

def usd_to_cad(usd_amount: float) -> float:
    rate = yf.Ticker("CADUSD=X").fast_info.get("lastPrice", 0.73)
    # CADUSD=X gives USD per CAD; we want CAD per USD = 1/rate
    cad_per_usd = 1.0 / rate if rate else 1.37
    return usd_amount * cad_per_usd

# Example
print(f"C${usd_to_cad(500_000):,.0f}")  # e.g. C$685,000
```

When reporting in Discord, always show both:
```
CEO bought $500,000 USD (C$685,000) on 2026-03-08
```

---

## Eligible Tickers for Insider Scanning

The FinClaw watchlist contains a mix of ticker types. Only a subset has SEC Form 4 data.

| Ticker Category | Examples | SEC Form 4? | Action |
|-----------------|----------|-------------|--------|
| US equities | AAPL, MSFT, NVDA, GOOGL, AMZN, TSLA, META | Yes | Scan |
| Canadian equities (.TO) | SHOP.TO, RY.TO, TD.TO, ENB.TO, CNR.TO, CP.TO, BCE.TO | No (SEDI) | Skip |
| US ETFs | SPY, QQQ | No (no insiders) | Skip |
| Canadian ETFs | XIU.TO, XIC.TO | No | Skip |
| Crypto | BTC-USD, ETH-USD, SOL-USD | No | Skip |

As of the current watchlist.json, the scannable US equities are:
`AAPL, MSFT, NVDA, GOOGL, AMZN, TSLA, META`

If new US equity tickers are added to watchlist.json, they are automatically included.

---

## Canadian Insider Data (Future Enhancement)

Canadian insider filings are reported to SEDI (System for Electronic Disclosure by
Insiders) at https://www.sedi.ca — not SEC EDGAR. SEDI is publicly accessible but does
not have a clean API. A future `canadian-insider-monitor` skill could scrape SEDI or
use a third-party provider. For now, Canadian tickers are silently skipped.

---

## Limitations and Edge Cases

1. **Reporting lag**: SEC rules require Form 4 filing within 2 business days of the
   transaction. There is an inherent 2-day delay between the actual buy and when this
   skill can detect it. This is acceptable for swing trade signals (not day trading).

2. **EDGAR search vs. XML parsing**: The EDGAR full-text search API returns filing
   metadata efficiently, but detailed transaction amounts require fetching and parsing
   the XML file for each accession number. This is the slower part of the scan.
   For a watchlist of 7 US equities, expect 15–45 seconds total scan time.

3. **Name disambiguation**: EDGAR full-text search for a ticker symbol (e.g., "AAPL")
   may return filings where "AAPL" appears in the text but is not the primary issuer.
   The XML parser validates the issuer ticker symbol in the `<issuerTradingSymbol>` field.

4. **Dark periods**: Most companies have trading blackout windows around earnings (usually
   the 30 days before an earnings report). Insider buys during blackout periods are illegal
   and extremely rare. If the automated system detects a high-value purchase very close
   to an earnings date, note it but do not over-weight — it may be a data quality issue.

5. **Score ceilings**: The insider signal is capped at +1 regardless of the dollar amount.
   A $10M CEO purchase does not score +2. The 5-dimension scoring system is designed to
   require convergence of multiple independent signals, not to be dominated by any one factor.

---

## Sample Discord Output

When the autonomous loop completes a scan and detects insider activity, the morning
briefing should include a dedicated section:

```
INSIDER BUY ACTIVITY — Last 30 Days
────────────────────────────────────
NVDA   HIGH    Jensen Huang (CEO) — $2,400,000 — 2026-03-08
               → NVDA score lifted to 4/5 — BUY ORDER PLACED

MSFT   MEDIUM  Christopher Young (Director) — $185,000 — 2026-03-05
               → MSFT score now 2/5 — on watchlist, no trade yet

AAPL   NONE    No insider purchases in last 30 days
AMZN   NONE    No insider purchases in last 30 days
GOOGL  SKIP    (N/A — no relevant data)
TSLA   NONE    No insider purchases in last 30 days
META   NONE    No insider purchases in last 30 days
────────────────────────────────────
Scanned 7 US equities | 1 HIGH | 1 MEDIUM | 5 NONE
```

---

## References

- SEC EDGAR Full-Text Search API: https://efts.sec.gov/LATEST/search-index
- SEC Form 4 Explanation: https://www.sec.gov/about/forms/form4data.pdf
- SEC EDGAR Rate Limits: https://www.sec.gov/privacy.htm#security
- Academic basis: Lakonishok & Lee (2001), "Are Insider Trades Informative?", Review of Financial Studies
