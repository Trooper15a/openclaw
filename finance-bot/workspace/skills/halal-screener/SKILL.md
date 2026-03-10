---
name: halal-screener
description: "Quick halal compliance check for a ticker. Returns APPROVED, HARAM, or NEEDS_REVIEW. Use this FIRST before any trade decision. Uses cached list for instant results on common tickers, falls back to revenue analysis for unknown tickers."
metadata:
  {
    "openclaw":
      {
        "emoji": "☪️",
        "requires": { "bins": ["python3"], "pip": ["requests"] },
      },
  }
---

# Halal Screener

## When to Use

- **Always run this skill before `stock-analysis`** on any ticker
- Before executing or recommending any trade
- When the user asks "is X halal?" or "can I buy X?"
- When scanning a watchlist for shariah compliance
- When onboarding a new ticker into the portfolio

## When NOT to Use

- After already confirming status this session (cache the result in memory for the session)
- For tickers already confirmed APPROVED in the same conversation turn

## Integration Rule

> If `halal-screener` returns `HARAM` — stop immediately. Do not run `stock-analysis`. Do not suggest the trade. Explain why and offer a halal alternative in the same sector if possible.
>
> If `halal-screener` returns `NEEDS_REVIEW` — inform the user, run the full review script, and do not execute a trade until status is resolved.
>
> If `halal-screener` returns `APPROVED` — proceed to `stock-analysis` normally.

## Setup

Install the required Python package once:

```bash
pip install requests
```

`requests` is used only for the fallback Yahoo Finance lookup when a ticker is not found in the cache. The cache path (`HALAL_SCREENER.md`) is read from disk — no network call required for cached tickers.

---

## How It Works

1. **Cache lookup (instant, ~0ms):** The script reads `HALAL_SCREENER.md` and checks the ticker against the pre-approved HALAL and HARAM lists. 90% of checks end here.
2. **Fallback — sector check (~1s):** If the ticker is not cached, it fetches basic company info from Yahoo Finance's public quote API and checks the sector/industry against haram categories.
3. **Fallback — keyword scan (~2s):** If the sector is ambiguous, it fetches the business summary and scans for haram keywords.
4. **Result:** Always returns a structured JSON result with status, reason, confidence, and source.

---

## Full Screener Script

```python
#!/usr/bin/env python3
"""
halal_screener.py
-----------------
Checks a ticker for halal compliance.
Usage: python3 halal_screener.py AAPL
       python3 halal_screener.py AAPL,MSFT,JPM   (batch mode)

Returns JSON. Exit code 0 = APPROVED, 1 = HARAM, 2 = NEEDS_REVIEW, 3 = ERROR
"""

import sys
import json
import re
import os
import pathlib

# ─── CONFIGURATION ────────────────────────────────────────────────────────────

# Path to the cached screener file. Adjust if your workspace path differs.
SCREENER_CACHE_PATH = pathlib.Path(
    os.path.expanduser("~/.openclaw/workspace-finclaw/strategy/HALAL_SCREENER.md")
)

# Haram keywords for business description scan (hard stop)
HARAM_KEYWORDS_HARD = [
    "alcohol", "beer", "wine", "spirits", "liquor", "brewery", "brewer",
    "tobacco", "cigarette", "cigar", "nicotine product",
    "casino", "gambling", "lottery", "sports betting", "wagering",
    "pork processing", "swine processing",
    "net interest margin", "interest income",          # bank-specific
    "adult entertainment", "pornograph",
]

# Keywords that trigger a NEEDS_REVIEW (soft warning)
HARAM_KEYWORDS_SOFT = [
    "defense contract", "weapons system", "ammunition", "firearms manufacturing",
    "interest-bearing", "leveraged loan", "mortgage banking",
]

# Haram GICS industries (exact match against Yahoo Finance 'industry' field)
HARAM_INDUSTRIES = [
    "banks—diversified", "banks—regional", "banks—global",
    "mortgage finance", "credit services",
    "beverages—brewers", "beverages—wineries & distilleries",
    "tobacco",
    "gambling", "casinos & gaming", "lottery",
    "aerospace & defense",                 # flag for review (not hard-haram — dual use)
]

# Hard-haram industries (no review needed)
HARD_HARAM_INDUSTRIES = [
    "banks—diversified", "banks—regional", "banks—global",
    "mortgage finance",
    "beverages—brewers", "beverages—wineries & distilleries",
    "tobacco",
    "gambling", "casinos & gaming", "lottery",
]

# ─── CACHE PARSER ─────────────────────────────────────────────────────────────

def load_cache(path: pathlib.Path) -> tuple[set, set]:
    """
    Parse HALAL_SCREENER.md and return:
      (approved_tickers: set[str], haram_tickers: set[str])

    Looks for markdown table rows that contain ticker symbols. Any ticker found
    in a section whose heading contains 'HARAM' or 'NEVER BUY' goes into the
    haram set; everything else in a table under a halal/approved heading goes
    into the approved set.
    """
    approved = set()
    haram = set()

    if not path.exists():
        return approved, haram

    in_haram_section = False
    in_approved_section = False

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip()

            # Detect section headers
            if line.startswith("#"):
                heading_lower = line.lower()
                if "haram" in heading_lower or "never buy" in heading_lower:
                    in_haram_section = True
                    in_approved_section = False
                elif any(kw in heading_lower for kw in [
                    "approved", "halal", "pre-approved", "canadian", "crypto"
                ]):
                    in_approved_section = True
                    in_haram_section = False
                else:
                    # Neutral section (rules, refresh schedule, etc.)
                    in_haram_section = False
                    in_approved_section = False
                continue

            # Parse markdown table rows: | TICKER | Company | Notes |
            if line.startswith("|") and "|" in line[1:]:
                cells = [c.strip() for c in line.strip("|").split("|")]
                if not cells:
                    continue
                candidate = cells[0].strip()
                # Valid ticker: 1-7 uppercase alphanumeric chars, optionally .TO suffix
                if re.match(r'^[A-Z]{1,5}(-USD|\.TO)?$', candidate):
                    if in_haram_section:
                        haram.add(candidate)
                    elif in_approved_section:
                        approved.add(candidate)

    return approved, haram


# ─── YAHOO FINANCE FALLBACK ────────────────────────────────────────────────────

def fetch_yahoo_info(ticker: str) -> dict:
    """
    Fetch basic company info from Yahoo Finance's v1 quote summary API.
    Returns a dict with keys: sector, industry, longBusinessSummary (lowercased).
    Falls back to empty dict on any error.
    """
    try:
        import requests
        url = (
            f"https://query1.finance.yahoo.com/v10/finance/quoteSummary/{ticker}"
            f"?modules=assetProfile"
        )
        headers = {"User-Agent": "Mozilla/5.0"}
        resp = requests.get(url, headers=headers, timeout=8)
        resp.raise_for_status()
        data = resp.json()
        profile = (
            data.get("quoteSummary", {})
                .get("result", [{}])[0]
                .get("assetProfile", {})
        )
        return {
            "sector": profile.get("sector", "").lower(),
            "industry": profile.get("industry", "").lower(),
            "summary": profile.get("longBusinessSummary", "").lower(),
        }
    except Exception as e:
        return {"sector": "", "industry": "", "summary": "", "error": str(e)}


def check_via_yahoo(ticker: str) -> dict:
    """
    Fallback check using live Yahoo Finance data.
    Returns a result dict.
    """
    info = fetch_yahoo_info(ticker)

    if "error" in info and not info["sector"]:
        return {
            "ticker": ticker,
            "status": "NEEDS_REVIEW",
            "reason": f"Could not fetch company data from Yahoo Finance: {info['error']}. Manual review required.",
            "confidence": "LOW",
            "source": "FALLBACK_ERROR",
        }

    industry = info["industry"]
    summary = info["summary"]

    # Hard haram industry match
    for haram_ind in HARD_HARAM_INDUSTRIES:
        if haram_ind in industry:
            return {
                "ticker": ticker,
                "status": "HARAM",
                "reason": f"Industry '{info['industry']}' is categorically haram (riba/alcohol/gambling/tobacco).",
                "confidence": "HIGH",
                "source": "FALLBACK_INDUSTRY",
            }

    # Defense is borderline — needs review
    if "aerospace & defense" in industry or "defense" in industry:
        return {
            "ticker": ticker,
            "status": "NEEDS_REVIEW",
            "reason": "Aerospace & defense sector — check what percentage of revenue comes from weapons vs. civilian programs.",
            "confidence": "MEDIUM",
            "source": "FALLBACK_INDUSTRY",
        }

    # Hard haram keyword scan on business description
    found_hard = [kw for kw in HARAM_KEYWORDS_HARD if kw in summary]
    if found_hard:
        return {
            "ticker": ticker,
            "status": "HARAM",
            "reason": f"Business description contains haram activity keywords: {', '.join(found_hard)}.",
            "confidence": "HIGH",
            "source": "FALLBACK_KEYWORD",
        }

    # Soft warning keywords — needs review
    found_soft = [kw for kw in HARAM_KEYWORDS_SOFT if kw in summary]
    if found_soft:
        return {
            "ticker": ticker,
            "status": "NEEDS_REVIEW",
            "reason": f"Business description contains borderline keywords: {', '.join(found_soft)}. Manual revenue analysis required.",
            "confidence": "MEDIUM",
            "source": "FALLBACK_KEYWORD",
        }

    # Passed all checks
    sector_note = f"{info['sector'].title()} / {info['industry'].title()}" if info["sector"] else "sector unknown"
    return {
        "ticker": ticker,
        "status": "APPROVED",
        "reason": f"No haram indicators found via automated check ({sector_note}). Not in cached list — add to HALAL_SCREENER.md after manual confirmation.",
        "confidence": "MEDIUM",
        "source": "FALLBACK_CLEAN",
    }


# ─── MAIN SCREENER ─────────────────────────────────────────────────────────────

def screen(ticker: str, approved: set, haram: set) -> dict:
    """
    Screen a single ticker. Returns a result dict.
    """
    ticker = ticker.upper().strip()

    # 1. Cache hit — HARAM (instant)
    if ticker in haram:
        # Map known haram categories to friendly reasons
        bank_tickers = {
            "JPM", "BAC", "WFC", "GS", "MS", "C",
            "TD", "RY", "BNS", "BMO", "CM",
            "TD.TO", "RY.TO", "BNS.TO", "BMO.TO", "CM.TO", "NA.TO",
        }
        alcohol_tickers = {"BUD", "TAP", "STZ", "SAM"}
        tobacco_tickers = {"MO", "PM", "BTI", "LO"}
        gambling_tickers = {"MGM", "LVS", "WYNN", "CZR", "PENN", "DKNG", "FLUT"}
        defense_tickers = {"LMT", "RTX", "NOC", "GD", "BA"}
        pork_tickers = {"HRL", "TSN", "WH"}

        if ticker in bank_tickers:
            reason = "Interest-based banking (riba) — categorically prohibited in Islamic finance."
        elif ticker in alcohol_tickers:
            reason = "Alcohol production or distribution — haram substance."
        elif ticker in tobacco_tickers:
            reason = "Tobacco / nicotine products — harmful and prohibited."
        elif ticker in gambling_tickers:
            reason = "Gambling / casinos / sports betting (maysir) — prohibited."
        elif ticker in defense_tickers:
            reason = "Primary revenue from weapons manufacturing — prohibited."
        elif ticker in pork_tickers:
            reason = "Pork processing or distribution — haram substance."
        else:
            reason = "Listed in HARAM cache in HALAL_SCREENER.md."

        return {
            "ticker": ticker,
            "status": "HARAM",
            "reason": reason,
            "confidence": "HIGH",
            "source": "CACHE",
        }

    # 2. Cache hit — APPROVED (instant)
    if ticker in approved:
        # Provide a brief reason based on known sector groupings
        tech = {
            "AAPL", "MSFT", "NVDA", "GOOGL", "META", "AMD", "INTC", "QCOM",
            "AVGO", "CRM", "ADBE", "NOW", "SNOW", "PLTR",
        }
        mobility = {"UBER", "LYFT", "ABNB", "SHOP", "SPOT", "NFLX", "AMZN"}
        retail = {"COST", "WMT", "TGT", "HD", "DIS"}
        pharma = {"PFE", "JNJ", "ABBV", "MRK", "LLY", "UNH"}
        energy = {"NEE", "ENPH", "FSLR", "SEDG"}
        etf = {"SPY", "QQQ", "XIU.TO"}
        tsx = {"SHOP.TO", "ENB.TO", "SU.TO", "CNQ.TO", "TRP.TO"}
        crypto = {"BTC-USD", "ETH-USD", "SOL-USD"}

        if ticker in tech:
            reason = "Technology hardware/software/cloud — no haram revenue streams."
        elif ticker in mobility:
            reason = "E-commerce or digital media platform — no haram revenue streams."
        elif ticker in retail:
            reason = "Retail / consumer services — no primary haram revenue (alcohol/tobacco <5% of revenue)."
        elif ticker in pharma:
            reason = "Healthcare / pharmaceuticals — conventional medicine is permissible."
        elif ticker in energy:
            reason = "Clean / renewable energy — permissible."
        elif ticker in etf:
            reason = "Diversified index ETF — broadly accepted as permissible under diversification principle."
        elif ticker in tsx:
            reason = "Canadian energy or infrastructure — permissible."
        elif ticker in crypto:
            reason = "Utility cryptocurrency — permissible for use; limit to 5% of portfolio and avoid leverage."
        else:
            reason = "Listed in APPROVED cache in HALAL_SCREENER.md."

        return {
            "ticker": ticker,
            "status": "APPROVED",
            "reason": reason,
            "confidence": "HIGH",
            "source": "CACHE",
        }

    # 3. Not in cache — run live fallback check
    return check_via_yahoo(ticker)


# ─── ENTRY POINT ──────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "Usage: python3 halal_screener.py TICKER [or TICKER1,TICKER2,...]"
        }, indent=2))
        sys.exit(3)

    raw_input = sys.argv[1]
    tickers = [t.strip() for t in raw_input.split(",") if t.strip()]

    # Load cache once
    approved, haram = load_cache(SCREENER_CACHE_PATH)

    results = []
    exit_code = 0  # defaults to APPROVED

    for ticker in tickers:
        result = screen(ticker, approved, haram)
        results.append(result)

        # Set exit code to worst status found
        if result["status"] == "HARAM":
            exit_code = 1
        elif result["status"] == "NEEDS_REVIEW" and exit_code != 1:
            exit_code = 2
        elif result["status"] == "ERROR" and exit_code not in (1, 2):
            exit_code = 3

    # Output
    if len(results) == 1:
        print(json.dumps(results[0], indent=2))
    else:
        print(json.dumps(results, indent=2))

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
```

---

## Usage Examples

### Single ticker (cached — instant)

```bash
python3 halal_screener.py AAPL
```

```json
{
  "ticker": "AAPL",
  "status": "APPROVED",
  "reason": "Technology hardware/software/cloud — no haram revenue streams.",
  "confidence": "HIGH",
  "source": "CACHE"
}
```

### Single ticker — HARAM (cached — instant)

```bash
python3 halal_screener.py JPM
```

```json
{
  "ticker": "JPM",
  "status": "HARAM",
  "reason": "Interest-based banking (riba) — categorically prohibited in Islamic finance.",
  "confidence": "HIGH",
  "source": "CACHE"
}
```

### Unknown ticker (fallback — live check)

```bash
python3 halal_screener.py TSLA
```

```json
{
  "ticker": "TSLA",
  "status": "APPROVED",
  "reason": "No haram indicators found via automated check (Consumer Cyclical / Auto Manufacturers). Not in cached list — add to HALAL_SCREENER.md after manual confirmation.",
  "confidence": "MEDIUM",
  "source": "FALLBACK_CLEAN"
}
```

### Batch mode

```bash
python3 halal_screener.py AAPL,JPM,NVDA,MGM
```

```json
[
  {"ticker": "AAPL", "status": "APPROVED", "reason": "Technology hardware/software/cloud...", "confidence": "HIGH", "source": "CACHE"},
  {"ticker": "JPM",  "status": "HARAM",    "reason": "Interest-based banking (riba)...",    "confidence": "HIGH", "source": "CACHE"},
  {"ticker": "NVDA", "status": "APPROVED", "reason": "Technology hardware/software/cloud...", "confidence": "HIGH", "source": "CACHE"},
  {"ticker": "MGM",  "status": "HARAM",    "reason": "Gambling / casinos...",               "confidence": "HIGH", "source": "CACHE"}
]
```

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | All tickers APPROVED |
| `1` | At least one ticker is HARAM |
| `2` | At least one ticker is NEEDS_REVIEW (no HARAM found) |
| `3` | Error (bad input or network failure) |

---

## Output Field Reference

| Field | Values | Description |
|-------|--------|-------------|
| `ticker` | String | The ticker as submitted (uppercased) |
| `status` | `APPROVED` / `HARAM` / `NEEDS_REVIEW` | Compliance verdict |
| `reason` | String | Plain-language explanation of the verdict |
| `confidence` | `HIGH` / `MEDIUM` / `LOW` | HIGH = from verified cache; MEDIUM = live automated check passed; LOW = data retrieval issue |
| `source` | `CACHE` / `FALLBACK_INDUSTRY` / `FALLBACK_KEYWORD` / `FALLBACK_CLEAN` / `FALLBACK_ERROR` | Where the decision came from |

---

## Adding New Tickers to the Cache

When the fallback returns `APPROVED` with `MEDIUM` confidence for a ticker you trade regularly:

1. Manually verify the company's business on their investor relations page
2. Confirm haram revenue <5% and interest-bearing debt <33% of assets
3. Add the ticker to the appropriate section of `HALAL_SCREENER.md`
4. On next run, it will resolve instantly from the cache with `HIGH` confidence

---

## Important Disclaimer

This screener is a best-effort automated tool. It is not a fatwa. For large investment decisions, consult a qualified Islamic finance scholar or a certified halal screening service (Zoya, Islamicly, Wahed). Rulings can differ between madhabs and scholars.
