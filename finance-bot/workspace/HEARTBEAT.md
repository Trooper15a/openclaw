# Heartbeat

Run this checklist on every heartbeat tick.

1. Check `alerts/queue.md` for any open position alerts — notify user immediately if found.
2. Verify no scheduled cron jobs have failed since last tick — check `logs/cron.log`.
3. If market hours (9:30am-4:00pm ET, Mon-Fri): scan watchlist for price alert triggers.
4. If pre-market (6:00am-9:30am ET): run blogwatcher feed scan with 12hr lookback,
   filter by watchlist, surface high-priority headlines.
5. If market hours: check earnings-tracker for any held positions reporting today or tomorrow.
   Alert user if an earnings date is within 48 hours for any position.
6. If digest time reached and user has `daily_digest` set: compile and send EOD summary
   including: price changes, P&L, triggered alerts, top news headlines from blogwatcher,
   and upcoming earnings from earnings-tracker.
7. If paper trading is active: confirm no live trading commands were queued accidentally.
8. If Sunday evening (8pm ET): run weekly earnings calendar scan for all watchlist tickers
   and portfolio holdings. Send earnings preview for the upcoming week.

Keep heartbeat actions fast and non-blocking. Defer heavy analysis to subagents.
