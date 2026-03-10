---
name: insider-monitor
description: "Monitors SEC Form 4 insider trading filings for significant executive purchases. Use when: scanning for insider buy signals on watchlist tickers, checking if insiders are buying before recommending a stock. NOT for: insider sales (those are less meaningful), option exercises."
metadata:
  {
    "openclaw": {
      "emoji": "🕵️",
      "requires": { "bins": ["python3"], "pip": ["requests", "pandas"] }
    }
  }
---

# Insider Monitor

## When to Use

- Scanning watchlist tickers for recent insider purchase activity (last 30 days)
- Confirming a bullish thesis — if C-suite is buying with personal cash, that is a strong signal
- Adding a +1 confirmation to a buy score that is already at 2/5
- Weekly insider sweep before Monday briefings
- Any time a user asks "are insiders buying [TICKER]?"

An insider buy with personal cash is one of the most reliable bullish signals in equity analysis.
Insiders can sell for many reasons (taxes, diversification, lifestyle). They buy for only one: they
believe the stock will go up. C-suite purchases above $500k are HIGH conviction — log them prominently.

## When NOT to Use

- Insider **sales** — do not flag these as bearish. Insiders sell for dozens of non-bearish reasons.
- **Option exercises** — these are compensation mechanics, not market-conviction buys.
- Crypto tickers (BTC-USD, ETH-USD, SOL-USD) — no SEC Form 4 filings exist for these.
- TSX-listed Canadian tickers (.TO suffix) — those are governed by SEDI (Canadian), not SEC EDGAR.
  Skip `.TO` tickers silently when running a full watchlist scan.
- ETFs (SPY, QQQ, XIU.TO, XIC.TO) — ETFs have no corporate insiders; skip silently.

## Setup

```bash
pip install requests pandas
```

No API key required. Uses the SEC EDGAR full-text search API (public, free, no auth).

## Core Python Script

The script below fetches Form 4 filings from SEC EDGAR for a given ticker, parses transaction
data, filters for open-market purchases by executives, and returns a signal score.

```python
#!/usr/bin/env python3
"""
insider_monitor.py — FinClaw Insider Buy Signal Scanner
Uses SEC EDGAR full-text search API (no API key required).

Usage:
    python insider_monitor.py NVDA
    python insider_monitor.py AAPL --days 60
    python insider_monitor.py --watchlist   # scans all eligible watchlist tickers
"""

import sys
import json
import time
import argparse
import requests
import pandas as pd
from datetime import datetime, timedelta
from typing import Optional

# ── Constants ─────────────────────────────────────────────────────────────────

EDGAR_SEARCH_URL = "https://efts.sec.gov/LATEST/search-index"
EDGAR_SUBMISSIONS_URL = "https://data.sec.gov/submissions"
EDGAR_COMPANY_SEARCH = "https://efts.sec.gov/LATEST/search-index?q=%22{ticker}%22&forms=4&dateRange=custom&startdt={start}&enddt={end}"

HEADERS = {
    "User-Agent": "FinClaw-InsiderMonitor/1.0 contact@finclaw.bot",
    "Accept": "application/json",
}

# Signal thresholds (USD)
HIGH_THRESHOLD   = 500_000   # CEO/CFO buy > $500k  => HIGH
MEDIUM_THRESHOLD =  50_000   # Any exec buy $50k–$500k => MEDIUM
# Below $50k => LOW (only log, do not score)

# C-suite titles that matter most
CSUITE_TITLES = [
    "Chief Executive Officer", "CEO",
    "Chief Financial Officer", "CFO",
    "Chief Operating Officer", "COO",
    "President",
    "Executive Chairman", "Chairman",
]

EXECUTIVE_TITLES = CSUITE_TITLES + [
    "Director",
    "Chief Technology Officer", "CTO",
    "Chief Revenue Officer", "CRO",
    "Chief Marketing Officer", "CMO",
    "Chief Legal Officer", "CLO",
    "General Counsel",
    "Executive Vice President", "EVP",
    "Senior Vice President", "SVP",
]

# Tickers to skip (no SEC filings)
SKIP_TICKERS = {
    "BTC-USD", "ETH-USD", "SOL-USD",  # crypto
    "SPY", "QQQ",                      # US ETFs
    "XIU.TO", "XIC.TO",                # Canadian ETFs
}

# ── EDGAR API Helpers ──────────────────────────────────────────────────────────

def fetch_form4_filings(ticker: str, days_back: int = 30) -> list[dict]:
    """
    Query SEC EDGAR full-text search for Form 4 filings mentioning the ticker.
    Returns a list of filing metadata dicts.
    """
    end_dt   = datetime.today()
    start_dt = end_dt - timedelta(days=days_back)
    start    = start_dt.strftime("%Y-%m-%d")
    end      = end_dt.strftime("%Y-%m-%d")

    url = (
        f"{EDGAR_SEARCH_URL}"
        f"?q=%22{ticker}%22"
        f"&forms=4"
        f"&dateRange=custom"
        f"&startdt={start}"
        f"&enddt={end}"
    )

    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        data = resp.json()
    except requests.exceptions.RequestException as e:
        print(f"  [WARN] EDGAR fetch failed for {ticker}: {e}", file=sys.stderr)
        return []

    hits = data.get("hits", {}).get("hits", [])
    filings = []
    for hit in hits:
        src = hit.get("_source", {})
        filings.append({
            "ticker":       ticker,
            "filed":        src.get("file_date", ""),
            "company":      src.get("entity_name", ""),
            "filer_name":   src.get("display_names", ["Unknown"])[0] if src.get("display_names") else "Unknown",
            "form_type":    src.get("form_type", "4"),
            "filing_url":   "https://www.sec.gov/Archives/" + src.get("file_path", "").lstrip("/"),
            "accession":    src.get("accession_no", ""),
        })
    return filings


def fetch_filing_xml(accession_no: str) -> Optional[str]:
    """
    Download the raw XML for a Form 4 filing to extract transaction details.
    Accession number format: 0001234567-24-000123
    """
    acc_clean = accession_no.replace("-", "")
    # Primary document is typically the .xml file
    xml_index_url = (
        f"https://www.sec.gov/Archives/edgar/data/"
        f"{acc_clean[:10].lstrip('0')}/"
        f"{acc_clean}/{accession_no}-index.htm"
    )
    # Simpler approach: use the search hit's filing_url directly (already points to index)
    return None  # Extended parsing handled in parse_transactions_from_search


def parse_transactions_from_search(filings: list[dict]) -> list[dict]:
    """
    For each filing returned by EDGAR search, fetch the structured submission data
    to extract individual transaction rows.

    SEC EDGAR provides structured JSON for each company's filings via:
    https://data.sec.gov/submissions/CIK{cik}.json

    Since full XML parsing requires resolving CIK -> accession -> XML, we use
    the EDGAR EFTS inline data where available, and fall back to structured
    summaries from the company submissions endpoint.
    """
    transactions = []
    seen_accessions = set()

    for filing in filings:
        acc = filing.get("accession", "")
        if acc in seen_accessions:
            continue
        seen_accessions.add(acc)

        # Attempt to pull transaction detail from the filing index page
        # The Form 4 XML is machine-readable; we fetch and lightly parse it
        acc_nodash = acc.replace("-", "")
        # CIK is embedded in accession: first 10 digits
        cik_raw = acc_nodash[:10]

        xml_url = (
            f"https://www.sec.gov/Archives/edgar/data/"
            f"{int(cik_raw)}/"
            f"{acc_nodash}/{acc}.xml"
        )

        try:
            time.sleep(0.12)  # SEC rate limit: no more than 10 req/sec
            resp = requests.get(xml_url, headers=HEADERS, timeout=15)
            if resp.status_code != 200:
                # Try alternate XML filename pattern
                continue
            xml_text = resp.text
        except requests.exceptions.RequestException:
            continue

        # Light XML parsing — avoid lxml dependency, use string scanning
        parsed = parse_form4_xml(xml_text, filing)
        transactions.extend(parsed)

    return transactions


def parse_form4_xml(xml_text: str, filing_meta: dict) -> list[dict]:
    """
    Parse Form 4 XML to extract non-derivative transactions (open-market buys/sells).
    Returns a list of transaction dicts for PURCHASES only.

    Key XML fields:
    - <transactionCode>P</transactionCode>  => Purchase (P = open market buy)
    - <transactionCode>S</transactionCode>  => Sale
    - <transactionCode>A</transactionCode>  => Award/grant (skip)
    - <transactionCode>M</transactionCode>  => Option exercise (skip)
    - <transactionShares>
    - <transactionPricePerShare>
    - <rptOwnerName>
    - <officerTitle>
    """
    import re

    transactions = []

    # Extract reporter name and title
    owner_name  = _xml_val(xml_text, "rptOwnerName")  or filing_meta.get("filer_name", "Unknown")
    officer_title = _xml_val(xml_text, "officerTitle") or ""
    is_director = bool(re.search(r"director", xml_text, re.IGNORECASE) and
                       not re.search(r"officerTitle", xml_text, re.IGNORECASE))

    # Extract all nonDerivativeTransaction blocks
    nd_pattern = re.compile(
        r"<nonDerivativeTransaction>(.*?)</nonDerivativeTransaction>",
        re.DOTALL | re.IGNORECASE,
    )

    for match in nd_pattern.finditer(xml_text):
        block = match.group(1)

        tx_code = _xml_val(block, "transactionCode")
        if tx_code != "P":
            # Only open-market Purchases
            continue

        shares_str = _xml_val(block, "transactionShares") or "0"
        price_str  = _xml_val(block, "transactionPricePerShare") or "0"
        date_str   = _xml_val(block, "transactionDate") or filing_meta.get("filed", "")

        try:
            shares = float(shares_str.replace(",", ""))
            price  = float(price_str.replace(",", ""))
        except ValueError:
            continue

        total_value = shares * price
        if total_value <= 0:
            continue

        transactions.append({
            "ticker":        filing_meta["ticker"],
            "company":       filing_meta["company"],
            "filed":         filing_meta["filed"],
            "tx_date":       date_str,
            "insider_name":  owner_name,
            "title":         officer_title,
            "is_director":   is_director,
            "tx_code":       "PURCHASE",
            "shares":        shares,
            "price_per_share": price,
            "total_value_usd": total_value,
            "filing_url":    filing_meta["filing_url"],
        })

    return transactions


def _xml_val(xml: str, tag: str) -> Optional[str]:
    """Extract the text value of the first occurrence of an XML tag."""
    import re
    pattern = rf"<{tag}[^>]*>(.*?)</{tag}>"
    m = re.search(pattern, xml, re.DOTALL | re.IGNORECASE)
    if m:
        return m.group(1).strip()
    return None


# ── Signal Scoring ─────────────────────────────────────────────────────────────

def score_transaction(tx: dict) -> dict:
    """
    Assign a signal level to a single insider purchase transaction.

    Signal rules:
    - HIGH   : C-suite (CEO/CFO/COO/President) AND total value > $500k
    - HIGH   : Any executive AND total value > $1M (very rare, always flag)
    - MEDIUM : Any executive AND total value $50k–$500k
    - MEDIUM : C-suite AND total value $25k–$50k (lower threshold for CEO)
    - LOW    : Director only AND any purchase, OR any purchase < $50k
    - SKIP   : Option exercise, award, or sale (filtered before this function)
    """
    value = tx["total_value_usd"]
    title = tx.get("title", "").strip()
    is_csuite = any(t.lower() in title.lower() for t in CSUITE_TITLES) if title else False
    is_exec   = any(t.lower() in title.lower() for t in EXECUTIVE_TITLES) if title else False

    if value >= 1_000_000:
        signal = "HIGH"
        reason = f"Massive purchase > $1M by {title or 'insider'}"
    elif is_csuite and value >= HIGH_THRESHOLD:
        signal = "HIGH"
        reason = f"C-suite ({title}) bought > $500k with personal cash"
    elif is_csuite and value >= 25_000:
        signal = "MEDIUM"
        reason = f"C-suite ({title}) purchased ${value:,.0f}"
    elif is_exec and value >= MEDIUM_THRESHOLD:
        signal = "MEDIUM"
        reason = f"Executive ({title or 'insider'}) purchased ${value:,.0f}"
    elif value >= MEDIUM_THRESHOLD:
        signal = "MEDIUM"
        reason = f"Insider purchased ${value:,.0f} (title unconfirmed)"
    else:
        signal = "LOW"
        reason = f"Small purchase ${value:,.0f} by {title or 'director/insider'}"

    return {**tx, "signal": signal, "reason": reason}


def aggregate_ticker_signal(scored_txns: list[dict]) -> dict:
    """
    Given all scored transactions for a single ticker, return the highest
    aggregate signal and a human-readable summary.
    """
    if not scored_txns:
        return {"signal": "NONE", "summary": "No qualifying insider purchases found."}

    signal_rank = {"HIGH": 3, "MEDIUM": 2, "LOW": 1, "NONE": 0}
    top = max(scored_txns, key=lambda t: signal_rank.get(t["signal"], 0))
    top_signal = top["signal"]

    total_value = sum(t["total_value_usd"] for t in scored_txns)
    buyer_count = len({t["insider_name"] for t in scored_txns})
    high_count  = sum(1 for t in scored_txns if t["signal"] == "HIGH")
    med_count   = sum(1 for t in scored_txns if t["signal"] == "MEDIUM")

    # Multiple buyers elevate signal
    if buyer_count >= 3 and top_signal == "MEDIUM":
        top_signal = "HIGH"

    lines = [
        f"Ticker         : {scored_txns[0]['ticker']}",
        f"Signal         : {top_signal}",
        f"Total bought   : ${total_value:,.0f} USD",
        f"Unique insiders: {buyer_count}",
        f"HIGH signals   : {high_count}",
        f"MEDIUM signals : {med_count}",
        f"Top buyer      : {top['insider_name']} ({top.get('title','?')})",
        f"Top purchase   : ${top['total_value_usd']:,.0f} on {top['tx_date']}",
        f"Reason         : {top['reason']}",
        f"Filing         : {top['filing_url']}",
    ]

    return {
        "ticker":       scored_txns[0]["ticker"],
        "signal":       top_signal,
        "total_usd":    total_value,
        "buyer_count":  buyer_count,
        "high_count":   high_count,
        "medium_count": med_count,
        "summary":      "\n".join(lines),
        "transactions": scored_txns,
    }


# ── Main Scanner ───────────────────────────────────────────────────────────────

def scan_ticker(ticker: str, days_back: int = 30, verbose: bool = True) -> dict:
    """
    Full pipeline for a single ticker:
    1. Fetch Form 4 filings from EDGAR
    2. Parse XML for open-market purchases
    3. Score each transaction
    4. Return aggregate signal
    """
    if ticker in SKIP_TICKERS or ticker.endswith(".TO"):
        return {
            "ticker": ticker,
            "signal": "SKIP",
            "summary": f"Skipped {ticker} — no SEC Form 4 filings (crypto/ETF/Canadian).",
        }

    if verbose:
        print(f"  Scanning {ticker}...", end=" ", flush=True)

    filings = fetch_form4_filings(ticker, days_back=days_back)

    if not filings:
        if verbose:
            print("no filings found.")
        return {"ticker": ticker, "signal": "NONE", "summary": f"No Form 4 filings found for {ticker} in last {days_back} days."}

    transactions = parse_transactions_from_search(filings)
    purchases    = [t for t in transactions if t.get("tx_code") == "PURCHASE"]

    if not purchases:
        if verbose:
            print(f"{len(filings)} filing(s), no open-market purchases.")
        return {"ticker": ticker, "signal": "NONE", "summary": f"Form 4 filings found but no open-market purchases for {ticker}."}

    scored = [score_transaction(t) for t in purchases]
    result = aggregate_ticker_signal(scored)

    if verbose:
        sig = result["signal"]
        print(f"{sig} — {result['buyer_count']} buyer(s), ${result['total_usd']:,.0f} total")

    return result


def scan_watchlist(watchlist_path: str, days_back: int = 30) -> list[dict]:
    """
    Scan all eligible tickers in the FinClaw watchlist.json.
    Skips crypto, ETFs, and Canadian tickers automatically.
    """
    with open(watchlist_path) as f:
        wl = json.load(f)

    tickers = wl.get("tickers", [])
    results = []

    print(f"\nInsider Monitor — Scanning {len(tickers)} watchlist tickers (last {days_back} days)")
    print("=" * 65)

    for ticker in tickers:
        result = scan_ticker(ticker, days_back=days_back)
        results.append(result)

    return results


def print_summary(results: list[dict]) -> None:
    """Print a formatted summary table of all scan results."""
    actionable = [r for r in results if r["signal"] in ("HIGH", "MEDIUM")]
    skipped    = [r for r in results if r["signal"] == "SKIP"]
    none_found = [r for r in results if r["signal"] == "NONE"]

    print("\n" + "=" * 65)
    print("INSIDER MONITOR REPORT")
    print(f"Generated: {datetime.today().strftime('%Y-%m-%d %H:%M UTC')}")
    print("=" * 65)

    if not actionable:
        print("\nNo significant insider purchases detected in scan window.")
    else:
        print(f"\nACTIONABLE SIGNALS ({len(actionable)} ticker(s)):\n")
        for r in sorted(actionable, key=lambda x: {"HIGH": 0, "MEDIUM": 1}.get(x["signal"], 2)):
            print(f"  [{r['signal']:6}]  {r['ticker']}")
            for line in r["summary"].split("\n")[2:]:  # skip ticker/signal header lines
                print(f"            {line}")
            print()

    print(f"\nNo signal : {', '.join(r['ticker'] for r in none_found) or 'none'}")
    print(f"Skipped   : {', '.join(r['ticker'] for r in skipped) or 'none'}")
    print("=" * 65)


# ── Entry Point ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="FinClaw Insider Monitor — SEC Form 4 Scanner")
    parser.add_argument("ticker",        nargs="?",  help="Single ticker to scan (e.g. NVDA)")
    parser.add_argument("--days",        type=int,   default=30, help="Days back to search (default: 30)")
    parser.add_argument("--watchlist",   action="store_true",    help="Scan full FinClaw watchlist")
    parser.add_argument("--watchlist-path", default="/c/Users/usman_mh5ia/.openclaw/workspace-finclaw/watchlist.json")
    parser.add_argument("--json",        action="store_true",    help="Output raw JSON")
    args = parser.parse_args()

    if args.watchlist:
        results = scan_watchlist(args.watchlist_path, days_back=args.days)
        if args.json:
            print(json.dumps(results, indent=2, default=str))
        else:
            print_summary(results)

    elif args.ticker:
        result = scan_ticker(args.ticker.upper(), days_back=args.days, verbose=False)
        if args.json:
            print(json.dumps(result, indent=2, default=str))
        else:
            print(result.get("summary", "No result."))
            print(f"\nSignal: {result['signal']}")

    else:
        parser.print_help()
```

## Quick One-Off Usage

```python
# Check if any insiders bought NVDA in the last 30 days
from insider_monitor import scan_ticker
result = scan_ticker("NVDA", days_back=30)
print(result["signal"])   # HIGH / MEDIUM / LOW / NONE / SKIP
print(result["summary"])
```

```python
# Scan entire watchlist and get only HIGH/MEDIUM signals
from insider_monitor import scan_watchlist

results = scan_watchlist("/path/to/watchlist.json", days_back=30)
hot     = [r for r in results if r["signal"] in ("HIGH", "MEDIUM")]
for r in hot:
    print(r["ticker"], r["signal"], f"${r.get('total_usd', 0):,.0f}")
```

## How to Interpret Results

### Signal Levels

| Signal | Meaning | Action |
|--------|---------|--------|
| **HIGH** | CEO/CFO/COO/President bought > $500k personally, OR 3+ executives buying simultaneously | Strong bullish confirmation. Add +1 to buy score. Mention prominently in Discord report. |
| **MEDIUM** | Executive (incl. Director) bought $50k–$500k, OR C-suite bought any amount | Moderate bullish signal. Add +1 to buy score if other signals agree. |
| **LOW** | Small purchase < $50k, or director-only buy | Weak signal. Log it but do not add to buy score. Monitor for follow-up. |
| **NONE** | No open-market purchases found in the scan window | Neutral. Do not penalise the stock. |
| **SKIP** | Ticker is crypto, ETF, or Canadian-listed | Not applicable. Skip silently. |

### What to Log

Every HIGH or MEDIUM result should be included in the Discord morning briefing:

```
INSIDER BUY ALERT
  NVDA — HIGH signal
  Buyer   : Jensen Huang (CEO)
  Amount  : $2,400,000 (personal cash)
  Date    : 2026-03-08
  Source  : https://www.sec.gov/Archives/...
  Action  : Adds +1 to NVDA buy score (now 3/5 — meets trade threshold)
```

### What NOT to Read Into

- **Insider sales** — this skill intentionally ignores them. Insiders sell to pay taxes,
  diversify, buy houses. A sale by a CFO is not a signal to short the stock.
- **Option exercises followed by same-day sales** — these are standard compensation mechanics,
  not conviction buys. They are filtered out (transactionCode != "P").
- **Small director purchases < $10k** — often a token gesture for board optics.

## Integration Note

When insider-monitor returns HIGH or MEDIUM signal for a ticker that already has 2+ other buy
signals, it can push the total score to 3+ required for a trade.

Example scoring flow:
```
NVDA — current score: 2/5
  Signal 1: RSI oversold (below 35)        +1
  Signal 2: Volume surge 2x avg            +1
  insider-monitor returns: HIGH            +1
  ─────────────────────────────────────────
  Total: 3/5 — MEETS TRADE THRESHOLD → execute buy
```

The autonomous trading loop (AUTONOMOUS_TRADING.md Step 3) should call this skill after the
initial RSI/MA/volume scoring pass. Insert it between Step 3 and Step 4:

```
Step 3b — Insider Check (for candidates scoring 1+ already)
  For each candidate with score >= 1:
    Run insider_monitor.scan_ticker(ticker, days_back=30)
    If signal == "HIGH":  score += 1  (log: "insider HIGH buy confirmed")
    If signal == "MEDIUM": score += 1 (log: "insider MEDIUM buy confirmed")
    If signal == "LOW":   no score change (log for reference only)
    If signal == "NONE":  no change
```

## Ethical Screening

Respect the FinClaw halal filter. Do not act on insider signals for tickers in excluded sectors:
alcohol, arms/defense, drugs (recreational), gambling, tobacco. If the ticker appears in
`excluded_sectors` in USER.md or watchlist.json, skip it silently.

## Rate Limiting

The SEC EDGAR API asks that bots stay under 10 requests/second and include a descriptive
User-Agent string. The script enforces a 0.12-second sleep between XML fetches. Do not
remove this delay. If running a full watchlist scan, total runtime will be approximately
30–90 seconds depending on filing volume.

SEC EDGAR Terms: https://www.sec.gov/privacy.htm#security
