# Economic Calendar Rules — FinClaw Trading Bot

## Purpose

This document defines the hard rules for how macro economic events affect trading decisions. These rules exist to protect capital from the violent, unpredictable price swings that occur around major economic releases. No trade is ever worth taking into a scheduled volatility event.

---

## Step 0 in Every Pre-Market Scan — Check the Calendar FIRST

Before RSI. Before news sentiment. Before watchlist scoring. Before any buy or sell decision.

```
PRE-MARKET SCAN ORDER:
  0. Run economic-calendar skill → get overall_verdict
  1. If GO_TO_CASH → sell all positions, stop scan, alert Discord
  2. If AVOID → skip new buys entirely, only manage existing positions
  3. If CAUTION → proceed with 50% reduced position sizes
  4. If CLEAR → proceed with normal rules
  5. Then run earnings-tracker check
  6. Then run stock analysis and scoring
```

If the economic calendar check fails for any reason (network error, bad data), default to CAUTION. Never default to CLEAR on an unknown.

---

## Hard Rules by Event Type

### FOMC — Federal Reserve Rate Decision

The single most market-moving scheduled event. Can cause 2-5% swings in indices within minutes.

| Timing | Rule |
|---|---|
| Day before FOMC | No new BUY positions. Do not add to existing positions. |
| FOMC day (before announcement) | No new BUY positions. No adds. Tighten mental stops. |
| FOMC day (after announcement) | No new BUY positions for remainder of day. Market digests for hours. |
| Day after FOMC | Proceed with caution (CAUTION-level rules). Full volatility may persist. |

Existing positions on FOMC day:
- Hold unless stop-loss is triggered (do not panic sell before announcement)
- Do NOT add to any position, even if the position is deeply profitable
- If the position has an unrealized gain greater than 10%, consider taking partial profits the day before FOMC

FOMC Minutes release (3 weeks after the meeting) follow the same rules as FOMC day.

---

### CPI — Consumer Price Index

Inflation data. If CPI comes in hotter or cooler than expected, the entire market reprices within seconds. Bonds, tech stocks, and rate-sensitive sectors move violently.

| Timing | Rule |
|---|---|
| 24 hours before CPI | No new BUY positions. |
| CPI day before 8:30 AM ET | Do not place any orders. Data releases at 8:30 AM ET. |
| CPI day, new buys after release | Allowed only after 30 minutes post-release, and only at 50% normal position size. |
| Day after CPI | Caution rules — 50% position size if new buys are considered. |

Existing positions on CPI day: Hold. Do not add. Let stops manage the downside.

---

### NFP — Non-Farm Payrolls (First Friday of each month)

The jobs report. Moves the market more than almost any other monthly release. Released at 8:30 AM ET on the first Friday of the month.

| Timing | Rule |
|---|---|
| Thursday before NFP | No new BUY positions after market close. |
| NFP Friday before 8:30 AM ET | No trades. Market is in pre-release limbo. |
| NFP Friday after 8:30 AM ET | Wait at least 30 minutes for volatility to settle. Then 50% position sizes only. |
| Day after NFP | Normal rules resume (assuming no other events). |

ADP Employment (Wednesday before NFP) is a MEDIUM impact precursor:
- Reduce new position sizes by 25% on ADP day
- ADP is not a hard AVOID, but be aware the market is already in "jobs week" mode

---

### PCE — Personal Consumption Expenditures Price Index

The Fed's preferred inflation measure. Less explosive than CPI on release, but can move markets significantly if it contradicts CPI data from the same month.

| Timing | Rule |
|---|---|
| PCE release day | No new BUY positions. Treat as equivalent to CPI day. |
| Day after PCE | CAUTION rules — 50% position sizes. |

---

### GDP — Gross Domestic Product (Quarterly)

GDP advance estimate (first release) can cause significant moves, especially if it shows contraction or misses badly.

| Timing | Rule |
|---|---|
| GDP release day | No new BUY positions. 50% position sizes if buys are considered after release. |
| Day after GDP | Normal rules resume unless the number was a major shock. |

Subsequent GDP revisions (second and third estimates) are MEDIUM impact — CAUTION rules apply.

---

### MEDIUM Impact Events (PPI, Retail Sales, Consumer Confidence, ISM)

These do not require a full AVOID, but they do require reduced exposure.

**Rule: On any MEDIUM impact event day, reduce all new position sizes by 25-50%.**

Specific guidance:
- **PPI**: Day before PPI, proceed normally. On PPI day, reduce new buys to 50% size.
- **Retail Sales**: CAUTION on release day. 25% size reduction is sufficient.
- **ISM Manufacturing / Services**: Released on the 1st and 3rd business days of the month. CAUTION on release morning — wait until after the number hits before placing orders.
- **Consumer Confidence / Sentiment (UoM)**: CAUTION on release day.
- **Weekly Jobless Claims**: Normally LOW impact. In a recession scare environment, treat as MEDIUM. If claims come in very high (e.g., above 400K), treat as HIGH for the rest of that day.

---

## The Go-to-Cash Rule

**If 3 or more HIGH IMPACT events occur within any rolling 7-day window:**

1. Sell all open positions before the first event fires
2. Hold 100% cash until all events in the window have passed
3. Log reason: "CALENDAR: GO_TO_CASH — [N] high impact events this week"
4. Alert Discord with the full list of events and dates
5. Resume normal scanning the day after the last event in the cluster

This rule exists because during macro event clusters (e.g., FOMC + CPI + NFP in one week), even well-structured trades can be destroyed by news crossfire. Capital preservation takes priority over opportunity.

---

## Existing Positions on High-Impact Days

Do NOT panic-sell existing positions simply because a macro event is approaching. The rules are:

| Condition | Action |
|---|---|
| Position is profitable, HIGH event today | Hold. Do not add. Let stop-loss manage downside. |
| Position is at breakeven, HIGH event today | Consider reducing by 50% to lock in neutrality. |
| Position is at a loss, HIGH event today | Hold unless stop-loss is hit. Do not average down. |
| Position has gain > 10% AND FOMC/CPI/NFP tomorrow | Take partial profits (sell 50%) today. |
| Position has gain > 5% AND HIGH event within 24h | Log as "pre-event profit lock candidate" — agent judgment call. |
| Stop-loss triggers during high-volatility event | Execute immediately. Do not wait for "calm." |

The key principle: on high-impact event days, manage existing risk, do not create new risk.

---

## Integration into the Pre-Market Scan Cron Job

The pre-market cron job (triggered daily before market open, typically 8:00-8:15 AM ET) must follow this exact order:

```
STEP 0 — ECONOMIC CALENDAR CHECK (this file)
  → Run: python3 economic_calendar.py --json
  → Read: overall_verdict field
  → If GO_TO_CASH: sell all, Discord alert, exit cron
  → If AVOID: set allow_new_buys = False, continue to position management only
  → If CAUTION: set position_size_multiplier = 0.50, continue
  → If CLEAR: set position_size_multiplier = 1.0, continue

STEP 1 — EXISTING POSITIONS (manage stops, take profits)
  → Always runs, regardless of calendar verdict
  → Stop-loss and take-profit rules still apply on high-impact days

STEP 2 — EARNINGS CHECK (earnings-tracker skill)
  → Only runs if allow_new_buys is True (i.e., calendar is not AVOID)
  → Removes any ticker reporting earnings within 48h from buy candidates

STEP 3 — WATCHLIST SCAN & SCORING
  → Only runs if allow_new_buys is True

STEP 4 — EXECUTE BUYS
  → Only runs if allow_new_buys is True
  → All position sizes multiplied by position_size_multiplier

STEP 5 — REPORT
  → Always runs
  → Include calendar verdict and upcoming events in Discord summary
```

The calendar check is not optional. It cannot be skipped. If the calendar fetch fails, the bot defaults to CAUTION and logs the failure.

---

## Discord Alert Format for Calendar Events

When the pre-market scan runs, include the calendar verdict in the Discord morning message:

```
MORNING BRIEF — 2026-03-10 08:05 ET

ECONOMIC CALENDAR: AVOID
  Today: CPI m/m at 8:30 AM ET [HIGH IMPACT]
  Thursday: Non-Farm Payrolls at 8:30 AM ET [HIGH IMPACT]

Trading mode: NO NEW POSITIONS TODAY
Existing positions: monitored, stops active
New buys: BLOCKED until Friday post-NFP
```

If verdict is CLEAR:
```
ECONOMIC CALENDAR: CLEAR
  No major events today or tomorrow.
  Next event: ISM Manufacturing on Monday (MEDIUM)
Trading mode: Normal rules apply.
```

---

## Why These Rules Exist

Economic releases are not stock-specific risks — they are systemic. A single CPI print can send the entire S&P 500 down 3% in 5 minutes, invalidating every technical setup on every stock in the watchlist simultaneously. No RSI reading, no earnings surprise history, no sentiment score can predict or survive that kind of move.

These rules do not prevent losses entirely. They prevent the specific category of losses that come from willfully trading into a known, scheduled volatility event. Every rule in this document corresponds to a real, documented market behavior:

- FOMC days have historically shown average intraday range of 2x normal
- CPI prints in 2022-2023 caused same-day moves of -4% to +5% in the S&P 500
- NFP Fridays regularly produce the highest-volume, most volatile sessions of the month

When in doubt: do nothing. Cash is a position. Missing a trade costs nothing. Trading into a CPI print and losing 7% on a position costs real money and real time to recover.
