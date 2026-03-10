# Halal Stock Screener — Pre-Built Cache

**Purpose:** Instant halal compliance decisions without re-analyzing every ticker from scratch.
**Coverage:** ~90% of commonly traded tickers resolved instantly from this cache.
**Refresh Schedule:** Re-verify the full list every quarter (Jan 1, Apr 1, Jul 1, Oct 1).
**Last Verified:** Q1 2026

---

## SCREENING PRINCIPLES

Islamic finance prohibits investment in companies whose primary business involves:

| Category | Reason |
|---|---|
| Banking / lending at interest | Riba (usury) — strictly prohibited |
| Alcohol production or distribution | Haram substance |
| Tobacco / nicotine products | Harmful and prohibited |
| Gambling / casinos / sports betting | Maysir (games of chance) |
| Defense / weapons manufacturing | Instruments of harm |
| Pork processing / distribution | Haram substance |
| Adult entertainment / pornography | Morally prohibited |
| DeFi lending tokens | Riba via protocol |

**Revenue tolerance:** A company is haram if >5% of revenue comes from haram activities (AAOIFI standard).
**Debt tolerance:** Companies with interest-bearing debt exceeding 33% of total assets are considered borderline — flag for NEEDS_REVIEW rather than instant APPROVED.

---

## PRE-APPROVED HALAL TICKERS

These tickers have been vetted. Return `APPROVED` instantly — no API call needed.

### US Equities — Technology

| Ticker | Company | Notes |
|--------|---------|-------|
| AAPL | Apple Inc. | Hardware, software, services — no haram revenue |
| MSFT | Microsoft Corp. | Cloud, productivity, gaming — permissible |
| NVDA | NVIDIA Corp. | Semiconductors, AI/GPU — permissible |
| GOOGL | Alphabet Inc. | Search, cloud, advertising — permissible |
| META | Meta Platforms | Social media, advertising — permissible |
| AMD | Advanced Micro Devices | Semiconductors — permissible |
| INTC | Intel Corp. | Semiconductors — permissible |
| QCOM | Qualcomm Inc. | Wireless technology — permissible |
| AVGO | Broadcom Inc. | Semiconductors, networking — permissible |
| CRM | Salesforce Inc. | Enterprise SaaS — permissible |
| ADBE | Adobe Inc. | Creative / document SaaS — permissible |
| NOW | ServiceNow Inc. | Enterprise workflow SaaS — permissible |
| SNOW | Snowflake Inc. | Cloud data platform — permissible |
| PLTR | Palantir Technologies | Data analytics (some defense contracts — monitor quarterly) |
| UBER | Uber Technologies | Ride-hailing, delivery — permissible |
| LYFT | Lyft Inc. | Ride-hailing — permissible |
| ABNB | Airbnb Inc. | Short-term rentals — permissible |
| SHOP | Shopify Inc. | E-commerce platform — permissible |
| SPOT | Spotify Technology | Music / podcast streaming — permissible |
| NFLX | Netflix Inc. | Streaming entertainment — permissible (content varies; platform itself is permissible) |

### US Equities — Consumer / Retail

| Ticker | Company | Notes |
|--------|---------|-------|
| AMZN | Amazon.com Inc. | E-commerce, cloud (AWS) — permissible |
| COST | Costco Wholesale | Warehouse retail — permissible (sells alcohol in stores but <5% revenue) |
| WMT | Walmart Inc. | General retail — permissible (monitor alcohol/tobacco shelf revenue) |
| TGT | Target Corp. | General retail — permissible |
| HD | Home Depot Inc. | Home improvement retail — permissible |
| DIS | Walt Disney Co. | Media, parks, streaming — permissible (media/entertainment only, no gaming/gambling revenue) |

### US Equities — Healthcare & Pharma

| Ticker | Company | Notes |
|--------|---------|-------|
| PFE | Pfizer Inc. | Pharmaceuticals — permissible (conventional medicine is halal) |
| JNJ | Johnson & Johnson | Pharma / MedTech — permissible |
| ABBV | AbbVie Inc. | Biopharmaceuticals — permissible |
| MRK | Merck & Co. | Pharmaceuticals — permissible |
| LLY | Eli Lilly and Co. | Pharmaceuticals — permissible |
| UNH | UnitedHealth Group | Managed healthcare / insurance — permissible (health insurance differs from interest banking) |

### US Equities — Clean Energy

| Ticker | Company | Notes |
|--------|---------|-------|
| NEE | NextEra Energy | Renewable energy leader — permissible |
| ENPH | Enphase Energy | Solar microinverters — permissible |
| FSLR | First Solar Inc. | Solar panel manufacturing — permissible |
| SEDG | SolarEdge Technologies | Solar inverters — permissible |

### US ETFs (Diversified — Permissible)

| Ticker | Fund | Notes |
|--------|------|-------|
| SPY | SPDR S&P 500 ETF | Broadly diversified index — permissible (small % of haram holdings diluted across 500 stocks; widely accepted by scholars for diversified index investing) |
| QQQ | Invesco Nasdaq-100 ETF | Tech-heavy index — permissible (same rationale as SPY; minimal haram exposure) |

---

### Canadian TSX Equities — Halal Approved

| Ticker | Company | Notes |
|--------|---------|-------|
| SHOP.TO | Shopify Inc. | E-commerce platform — permissible |
| ENB.TO | Enbridge Inc. | Energy infrastructure / pipelines — permissible |
| XIU.TO | iShares S&P/TSX 60 ETF | Diversified Canadian index — permissible (contains some bank exposure; accepted under diversification principle) |
| SU.TO | Suncor Energy | Oil sands energy production — permissible |
| CNQ.TO | Canadian Natural Resources | Oil & gas production — permissible |
| TRP.TO | TC Energy Corp. | Natural gas pipelines — permissible |

---

### Crypto (Small Allocation — Use with Caution)

Scholars differ on cryptocurrency permissibility. The following are the most widely accepted as permissible when used for utility, not speculation:

| Ticker | Asset | Status | Notes |
|--------|-------|--------|-------|
| BTC-USD | Bitcoin | APPROVED | Most widely accepted as permissible; store of value utility |
| ETH-USD | Ethereum | APPROVED | Permissible for utility and smart contract use |
| SOL-USD | Solana | APPROVED | Permissible for utility |

**Crypto hard rules:**
- Maximum allocation: 5% of portfolio (high volatility, speculative)
- Never buy DeFi lending tokens — they generate yield via interest (riba)
- Never buy casino/gambling protocol tokens (e.g., Rollbit, Shuffle tokens)
- Never use leverage or margin on crypto

---

## HARAM TICKERS — NEVER BUY

These tickers are permanently blocked. Return `HARAM` instantly. Do not analyze. Do not execute trades.

### Banks / Interest-Based Finance (Riba)

| Ticker | Company |
|--------|---------|
| JPM | JPMorgan Chase |
| BAC | Bank of America |
| WFC | Wells Fargo |
| GS | Goldman Sachs |
| MS | Morgan Stanley |
| C | Citigroup |
| TD | Toronto-Dominion Bank (US-listed) |
| RY | Royal Bank of Canada (US-listed) |
| BNS | Bank of Nova Scotia (US-listed) |
| BMO | Bank of Montreal (US-listed) |
| CM | Canadian Imperial Bank of Commerce (US-listed) |
| TD.TO | Toronto-Dominion Bank (TSX) |
| RY.TO | Royal Bank of Canada (TSX) |
| BNS.TO | Bank of Nova Scotia (TSX) |
| BMO.TO | Bank of Montreal (TSX) |
| CM.TO | CIBC (TSX) |
| NA.TO | National Bank of Canada (TSX) |

### Alcohol

| Ticker | Company |
|--------|---------|
| BUD | Anheuser-Busch InBev |
| TAP | Molson Coors Beverage |
| STZ | Constellation Brands |
| SAM | Boston Beer Company |

### Tobacco / Nicotine

| Ticker | Company |
|--------|---------|
| MO | Altria Group |
| PM | Philip Morris International |
| BTI | British American Tobacco |
| LO | Lorillard (reference — acquired by RAI) |

### Gambling / Casinos

| Ticker | Company |
|--------|---------|
| MGM | MGM Resorts International |
| LVS | Las Vegas Sands |
| WYNN | Wynn Resorts |
| CZR | Caesars Entertainment |
| PENN | PENN Entertainment |
| DKNG | DraftKings (sports betting) |
| FLUT | Flutter Entertainment (sports betting) |

### Defense / Weapons Manufacturing

| Ticker | Company |
|--------|---------|
| LMT | Lockheed Martin |
| RTX | RTX Corp (Raytheon) |
| NOC | Northrop Grumman |
| GD | General Dynamics |
| BA | Boeing (primary defense revenue) |

### Pork Processing

| Ticker | Company |
|--------|---------|
| HRL | Hormel Foods (SPAM, pork products) |
| TSN | Tyson Foods (significant pork processing) |
| WH | Smithfield Foods parent (pork processing) |

---

## BORDERLINE / NEEDS_REVIEW TICKERS

These require a quick revenue analysis before any trade decision.

| Ticker | Company | Issue |
|--------|---------|-------|
| MFC.TO | Manulife Financial | Insurance is borderline — check if investment income is primarily interest-based |
| SLF.TO | Sun Life Financial | Same as MFC — insurance/wealth management |
| COST | Costco | Sells alcohol — confirm <5% of total revenue |
| WMT | Walmart | Sells alcohol and tobacco — confirm <5% of total revenue |
| PLTR | Palantir | Government/defense contracts — confirm <33% of revenue from weapons programs |
| DIS | Walt Disney | Monitor for gambling expansion (sports betting partnerships) |
| T | AT&T | Telecom — check debt-to-assets ratio (high leverage is borderline) |
| VZ | Verizon | Same as AT&T |

---

## QUICK CHECK RULES — FOR TICKERS NOT ON ANY LIST

When a ticker is not found in the APPROVED or HARAM cache above, follow this process:

### Step 1 — Sector Red-Flag Check (instant)
Check the company's GICS sector/industry from Yahoo Finance `.info`:
- `sector` = "Financial Services" + `industry` contains "Banks" → **HARAM (riba)**
- `industry` contains any of: "Beverages—Brewers", "Beverages—Wineries", "Tobacco" → **HARAM**
- `industry` contains "Gambling", "Casinos", "Lottery" → **HARAM**
- `industry` contains "Defense", "Aerospace & Defense" → **Flag for review** (some are dual-use civilian)
- `industry` contains "Drug Manufacturers" → **APPROVED** (conventional medicine is halal)

### Step 2 — Keyword Scan on Business Description
Fetch `longBusinessSummary` from Yahoo Finance and scan for haram keywords:
- Hard haram keywords: `alcohol`, `beer`, `wine`, `spirits`, `liquor`, `tobacco`, `cigarette`, `casino`, `gambling`, `lottery`, `pork`, `swine`, `interest income`, `net interest margin`, `adult entertainment`
- Soft warning keywords (flag for review): `defense contracts`, `weapons systems`, `ammunition`, `firearms`, `interest-bearing`, `leveraged loans`

### Step 3 — Revenue Concentration Check
If soft warnings appear, check:
- Is the haram activity >5% of total revenue? → **HARAM**
- Is interest-bearing debt >33% of total assets? → **NEEDS_REVIEW** (flag, do not auto-approve)
- Otherwise → **APPROVED** with caveat noted

### Step 4 — Return Result
Always return a structured result:
```json
{
  "ticker": "XYZ",
  "status": "APPROVED | HARAM | NEEDS_REVIEW",
  "reason": "Plain-language explanation",
  "confidence": "HIGH | MEDIUM | LOW",
  "source": "CACHE | QUICK_CHECK"
}
```

---

## REFRESH SCHEDULE

| Quarter | Review Date | Action |
|---------|-------------|--------|
| Q1 | January 1 | Re-verify all APPROVED tickers for business model changes |
| Q2 | April 1 | Re-verify all APPROVED tickers |
| Q3 | July 1 | Re-verify all APPROVED tickers |
| Q4 | October 1 | Re-verify all APPROVED tickers + full HARAM list audit |

**Triggers for immediate re-verification (outside schedule):**
- A company announces merger with a haram-sector business
- A company launches a new gambling, alcohol, or weapons product line
- A bank acquires a previously approved company
- News alerts indicate significant revenue shift into haram categories

---

## IMPORTANT DISCLAIMER

This screener is a best-effort tool based on publicly available information and general Islamic finance principles (primarily AAOIFI standards). It is not a fatwa. For large investments, consult a qualified Islamic finance scholar or a certified halal screening service (e.g., Zoya, Islamicly, Wahed). Rulings can differ between madhabs and scholars.
