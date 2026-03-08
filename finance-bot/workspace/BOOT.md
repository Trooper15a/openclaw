# Boot

Run this checklist on every gateway restart or fresh session start.

1. Load `USER.md` — read user preferences, risk profile, and notification settings.
2. Check trading mode — if `live_trading_enabled: yes`, send a prominent warning to the
   user before proceeding. Confirm paper trading is disabled intentionally.
3. Verify required environment variables are set (DISCORD_BOT_TOKEN or TELEGRAM_BOT_TOKEN,
   MOOMOO_OPEND_HOST if live trading). Halt and alert user if any are missing.
4. Check for upstream updates — run `bash finance-bot/scripts/auto-update.sh --dry-run`
   to see if new commits are available from openclaw/openclaw main. Report to user if
   updates are pending (run from openclaw repo root) (Watchtower handles Docker image updates automatically).
5. Check skills are installed — run `clawhub list` and verify `skill-vetter`, `agentguard`,
   `coingecko`, `portfolio-watcher`, `tavily`, and `earnings-tracker` are present.
   If missing, prompt user to run BOOTSTRAP.md first.
6. Initialize blogwatcher — verify `feeds.json` exists in workspace root. If missing,
   create it from the default feed list in the `blogwatcher` skill.
7. Start monitor background subagent — pass current watchlist from USER.md.
8. Register cron jobs:
   - 6:00am ET — blogwatcher pre-market news scan (12hr lookback, filter by watchlist)
   - 9:30am ET — market open briefing (prices + news + earnings calendar)
   - 4:00pm ET — market close digest (EOD summary + news + position P&L)
   - Weekly Sunday 8pm ET — earnings calendar scan for the upcoming week
9. Read today's memory file (`memory/YYYY-MM-DD.md`) — summarize key context for the session.
10. Send startup confirmation to user's preferred channel with: mode (paper/live), watchlist
    size, installed skills count, next scheduled briefing time, update status, and any
    unresolved alerts from the previous session.

Boot complete. Await user input or first heartbeat tick.
