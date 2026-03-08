---
name: blogwatcher
description: "Monitors RSS/Atom feeds from financial news sources, analyst blogs, SEC filings, and crypto feeds. Surfaces new articles relevant to the user's watchlist. Use when: (1) morning briefing needs latest headlines, (2) user asks 'any news today', (3) monitoring SEC filings for held positions, (4) tracking analyst blogs for sector insights. NOT for: deep article analysis (use web_fetch + summarize), real-time price data (use finance-monitor)."
metadata:
  {
    "openclaw":
      {
        "emoji": "📡",
        "requires": { "bins": ["python3", "curl"] },
      },
  }
---

# Blogwatcher — Financial RSS Feed Monitor

## When to Use

- Morning briefings — pull latest headlines before market open
- User asks "any news today?" or "what's happening with NVDA?"
- Monitoring SEC EDGAR for new filings on held positions
- Tracking macro/Fed commentary from analyst blogs
- End-of-day digest — summarize what published during the session

## When NOT to Use

- Deep-dive article reading — fetch the full URL with `web_fetch` or `summarize` skill
- Real-time price data — use `finance-monitor`
- Social media sentiment — use `x-research` or `market-sentiment`

## Setup

Install the Python RSS parser:

```bash
pip install feedparser pytz
```

No API keys needed. All feeds are public RSS/Atom endpoints.

## Default Financial Feeds

The feed list is stored in `feeds.json` at the workspace root. Create it on first use:

```json
{
  "feeds": [
    {
      "name": "Reuters Business",
      "url": "https://www.reutersagency.com/feed/?best-topics=business-finance&post_type=best",
      "category": "news",
      "priority": "high"
    },
    {
      "name": "CNBC Top News",
      "url": "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=100003114",
      "category": "news",
      "priority": "high"
    },
    {
      "name": "Bloomberg Markets",
      "url": "https://feeds.bloomberg.com/markets/news.rss",
      "category": "news",
      "priority": "high"
    },
    {
      "name": "Yahoo Finance Top Stories",
      "url": "https://finance.yahoo.com/news/rssindex",
      "category": "news",
      "priority": "medium"
    },
    {
      "name": "MarketWatch Top Stories",
      "url": "https://feeds.marketwatch.com/marketwatch/topstories/",
      "category": "news",
      "priority": "medium"
    },
    {
      "name": "MarketWatch Earnings",
      "url": "https://feeds.marketwatch.com/marketwatch/marketpulse/",
      "category": "earnings",
      "priority": "medium"
    },
    {
      "name": "SEC EDGAR Full-Text Filings",
      "url": "https://www.sec.gov/cgi-bin/browse-edgar?action=getcurrent&type=&dateb=&owner=include&count=40&search_text=&start=0&output=atom",
      "category": "filings",
      "priority": "high"
    },
    {
      "name": "SEC EDGAR Company Search (customizable per ticker)",
      "url": "https://efts.sec.gov/LATEST/search-index?q=%22NVIDIA%22&dateRange=custom&startdt=2026-01-01&enddt=2026-12-31&forms=10-K,10-Q,8-K",
      "category": "filings",
      "priority": "high",
      "notes": "Replace NVIDIA with company name. Use web_fetch for this one — not a standard RSS feed."
    },
    {
      "name": "CoinDesk",
      "url": "https://www.coindesk.com/arc/outboundfeeds/rss/",
      "category": "crypto",
      "priority": "medium"
    },
    {
      "name": "The Block",
      "url": "https://www.theblock.co/rss.xml",
      "category": "crypto",
      "priority": "medium"
    },
    {
      "name": "Federal Reserve Press Releases",
      "url": "https://www.federalreserve.gov/feeds/press_all.xml",
      "category": "macro",
      "priority": "high"
    },
    {
      "name": "Calculated Risk (macro/housing blog)",
      "url": "https://www.calculatedriskblog.com/feeds/posts/default?alt=rss",
      "category": "macro",
      "priority": "low"
    },
    {
      "name": "Matt Levine - Money Stuff (Bloomberg)",
      "url": "https://feedpress.me/moneystuff",
      "category": "commentary",
      "priority": "low"
    }
  ]
}
```

## Key Commands

### Fetch all feeds and return recent articles

```python
import feedparser
import json
from datetime import datetime, timedelta
import pytz

def load_feeds(feeds_path: str = "feeds.json") -> list:
    with open(feeds_path) as f:
        return json.load(f)["feeds"]

def fetch_feed(feed: dict, hours_back: int = 24) -> list:
    """Fetch a single RSS feed and return articles from the last N hours."""
    try:
        d = feedparser.parse(feed["url"])
    except Exception as e:
        return [{"error": f"Failed to parse {feed['name']}: {e}"}]

    et = pytz.timezone("America/New_York")
    cutoff = datetime.now(et) - timedelta(hours=hours_back)
    articles = []

    for entry in d.entries[:20]:  # cap per feed
        # Parse published date — feedparser normalizes to struct_time
        published = None
        if hasattr(entry, "published_parsed") and entry.published_parsed:
            published = datetime(*entry.published_parsed[:6], tzinfo=pytz.utc)
        elif hasattr(entry, "updated_parsed") and entry.updated_parsed:
            published = datetime(*entry.updated_parsed[:6], tzinfo=pytz.utc)

        # Skip old articles if we have a date
        if published and published.astimezone(et) < cutoff:
            continue

        articles.append({
            "source": feed["name"],
            "category": feed.get("category", "general"),
            "priority": feed.get("priority", "medium"),
            "title": entry.get("title", "No title"),
            "link": entry.get("link", ""),
            "published": published.astimezone(et).strftime("%Y-%m-%d %H:%M ET") if published else "Unknown",
            "summary": entry.get("summary", "")[:200],  # truncate long summaries
        })

    return articles

def fetch_all_feeds(hours_back: int = 24) -> list:
    feeds = load_feeds()

    # Fetch all feeds in parallel — 13 feeds serially takes ~15s, parallel takes ~3s
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=6) as pool:
        results = pool.map(lambda f: fetch_feed(f, hours_back), feeds)
    all_articles = [a for batch in results for a in batch]

    # Sort by priority then by time
    priority_order = {"high": 0, "medium": 1, "low": 2}
    all_articles.sort(key=lambda a: (priority_order.get(a["priority"], 1), a["published"]))
    return all_articles

articles = fetch_all_feeds(hours_back=12)
for a in articles[:25]:  # top 25 articles
    print(f"[{a['category'].upper()}] {a['title']}")
    print(f"  Source: {a['source']} | {a['published']}")
    print(f"  {a['link']}")
    print()
```

### Filter articles by watchlist tickers

```python
import os
import re

def filter_by_watchlist(articles: list, watchlist: list = None) -> list:
    """Filter articles whose title or summary mentions a watchlist ticker or company name."""
    if watchlist is None:
        raw = os.environ.get("FINANCE_MONITOR_WATCHLIST", "AAPL,MSFT,NVDA,BTC-USD,ETH-USD")
        watchlist = [t.strip() for t in raw.split(",")]

    # Map common tickers to company name keywords for better matching
    ticker_keywords = {
        "AAPL": ["apple", "aapl", "iphone"],
        "MSFT": ["microsoft", "msft", "azure"],
        "NVDA": ["nvidia", "nvda", "jensen"],
        "GOOGL": ["google", "alphabet", "googl"],
        "AMZN": ["amazon", "amzn", "aws"],
        "TSLA": ["tesla", "tsla", "elon musk"],
        "META": ["meta", "facebook", "zuckerberg"],
        "BTC-USD": ["bitcoin", "btc"],
        "ETH-USD": ["ethereum", "eth"],
        "SOL-USD": ["solana", "sol"],
    }

    matched = []
    for article in articles:
        text = (article["title"] + " " + article.get("summary", "")).lower()
        for ticker in watchlist:
            base = ticker.split("-")[0].lower()
            keywords = ticker_keywords.get(ticker, [base])
            for kw in keywords:
                if kw.lower() in text:
                    article["matched_ticker"] = ticker
                    matched.append(article)
                    break
            else:
                continue
            break

    return matched

relevant = filter_by_watchlist(articles)
print(f"--- {len(relevant)} articles matching your watchlist ---")
for a in relevant:
    print(f"  [{a['matched_ticker']}] {a['title']}")
    print(f"    {a['link']}")
```

### Fetch SEC filings for a specific company

```python
import feedparser

def get_sec_filings(company: str, forms: str = "10-K,10-Q,8-K") -> list:
    """Search SEC EDGAR full-text search for recent filings."""
    url = f"https://efts.sec.gov/LATEST/search-index?q=%22{company}%22&forms={forms}"
    # Note: EDGAR full-text search is not a standard RSS feed.
    # Use web_fetch for this endpoint and parse JSON response.
    # Fallback: use the EDGAR ATOM feed filtered by company CIK.

    # Simple approach: use EDGAR company search RSS
    cik_url = f"https://www.sec.gov/cgi-bin/browse-edgar?company={company}&CIK=&type={forms.split(',')[0]}&dateb=&owner=include&count=10&search_text=&action=getcompany&output=atom"
    d = feedparser.parse(cik_url)

    filings = []
    for entry in d.entries[:10]:
        filings.append({
            "title": entry.get("title", ""),
            "link": entry.get("link", ""),
            "updated": entry.get("updated", ""),
            "summary": entry.get("summary", "")[:300],
        })
    return filings

filings = get_sec_filings("NVIDIA")
for f in filings:
    print(f"  {f['title']}")
    print(f"    {f['link']}")
```

## Cron Integration

Register these cron jobs in BOOT.md:

- **6:00 AM ET** — Pre-market news scan: `fetch_all_feeds(hours_back=12)`, filter by watchlist, include in morning briefing
- **12:00 PM ET** — Midday check: `fetch_all_feeds(hours_back=6)`, surface only high-priority or watchlist-relevant articles
- **4:30 PM ET** — Post-close digest: `fetch_all_feeds(hours_back=10)`, include in EOD summary

## Output Format

### Morning News Briefing Section

```
NEWS BRIEFING — 2026-03-06 06:00 ET (pre-market)

HIGH PRIORITY
  [FILINGS] NVIDIA Corp files 10-K annual report with SEC
    Source: SEC EDGAR | 2026-03-05 18:30 ET
    https://www.sec.gov/...

  [NEWS] Fed's Waller signals support for June rate cut
    Source: Reuters Business | 2026-03-06 05:45 ET
    https://reuters.com/...

WATCHLIST MENTIONS
  [NVDA] NVIDIA data center revenue beats estimates by 15%
    Source: CNBC | 2026-03-05 22:10 ET

  [BTC-USD] Bitcoin ETF inflows hit $500M as BTC tests $85K
    Source: CoinDesk | 2026-03-06 04:20 ET

  [AAPL] Apple delays AI rollout to fall, sources say
    Source: Bloomberg | 2026-03-05 19:00 ET

OTHER NOTABLE
  [MACRO] US jobs report Friday — consensus 180K, watch for revision
    Source: MarketWatch | 2026-03-06 05:00 ET
```

## Adding Custom Feeds

To add a new feed, edit `feeds.json`:

```python
import json

def add_feed(name: str, url: str, category: str = "custom", priority: str = "medium"):
    with open("feeds.json") as f:
        config = json.load(f)
    config["feeds"].append({
        "name": name,
        "url": url,
        "category": category,
        "priority": priority,
    })
    with open("feeds.json", "w") as f:
        json.dump(config, f, indent=2)

# Example: add a specific analyst's blog
add_feed("Stratechery", "https://stratechery.com/feed/", category="commentary", priority="low")
```
