#!/usr/bin/env python3
import json, os, re
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

WORKSPACE = "/workspace"

def read_file(path, default=""):
    try:
        with open(path) as f:
            return f.read()
    except:
        return default

def get_trading_mode():
    """Read trading mode from USER.md"""
    raw = read_file(f"{WORKSPACE}/USER.md", "")
    if "LIVE" in raw and "Current mode:** `LIVE`" in raw:
        return "LIVE"
    return "PAPER"

def get_portfolio():
    try:
        with open(f"{WORKSPACE}/portfolio.json") as f:
            return json.load(f)
    except:
        return {"positions": [], "cash": 0, "paper_trading": True, "currency": "CAD"}

def get_trades():
    raw = read_file(f"{WORKSPACE}/paper-trading/trades.md")
    trades = []
    for line in raw.splitlines():
        if line.startswith("|") and "---" not in line and "Date" not in line:
            cols = [c.strip() for c in line.strip("|").split("|")]
            if len(cols) >= 6 and cols[0]:
                trades.append({
                    "date": cols[0], "ticker": cols[1], "action": cols[2],
                    "shares": cols[3], "price": cols[4], "total": cols[5],
                    "notes": cols[6] if len(cols) > 6 else ""
                })
    return trades

def get_alerts():
    raw = read_file(f"{WORKSPACE}/alerts/queue.md", "No active alerts.")
    return raw

def get_memory():
    today = datetime.now().strftime("%Y-%m-%d")
    return read_file(f"{WORKSPACE}/memory/{today}.md", "No memory log for today yet.")

def get_watchlist():
    try:
        with open(f"{WORKSPACE}/watchlist.json") as f:
            return json.load(f)
    except:
        return {"tickers": os.environ.get("FINANCE_MONITOR_WATCHLIST", "AAPL,MSFT,NVDA").split(",")}

def render_dashboard():
    portfolio = get_portfolio()
    trades = get_trades()
    alerts = get_alerts()
    memory = get_memory()
    watchlist = get_watchlist()
    tickers = watchlist.get("tickers", [])
    trading_mode = get_trading_mode()

    if trading_mode == "LIVE":
        mode_badge = '<span class="badge live">⚠️ LIVE TRADING — REAL MONEY</span>'
        mode_banner = '<div class="live-banner">⚠️ LIVE TRADING MODE — Real money at risk. Double-check every order.</div>'
    else:
        mode_badge = '<span class="badge paper">📋 PAPER TRADING</span>'
        mode_banner = '<div class="paper-banner">📋 Paper Trading Mode — Simulated orders only. No real money involved.</div>'
    currency = portfolio.get("currency", "CAD")

    positions_html = ""
    for p in portfolio.get("positions", []):
        positions_html += f"""
        <tr>
            <td><strong>{p.get('ticker','')}</strong></td>
            <td>{p.get('shares','')}</td>
            <td>{p.get('avg_cost','')}</td>
            <td>{p.get('current_price','—')}</td>
            <td>{p.get('pnl','—')}</td>
        </tr>"""
    if not portfolio.get("positions"):
        positions_html = '<tr><td colspan="5" style="text-align:center;color:#888">No open positions yet</td></tr>'

    trades_html = ""
    for t in trades[-20:]:
        action_class = "buy" if t["action"].upper() == "BUY" else "sell"
        trades_html += f"""
        <tr>
            <td>{t['date']}</td>
            <td><strong>{t['ticker']}</strong></td>
            <td><span class="badge {action_class}">{t['action']}</span></td>
            <td>{t['shares']}</td>
            <td>{t['price']}</td>
            <td>{t['total']}</td>
        </tr>"""
    if not trades:
        trades_html = '<tr><td colspan="6" style="text-align:center;color:#888">No trades yet</td></tr>'

    watchlist_html = " ".join([f'<span class="ticker-chip">{t}</span>' for t in tickers])

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>FinClaw Dashboard</title>
<meta http-equiv="refresh" content="60">
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0d1117; color: #e6edf3; min-height: 100vh; }}
  .header {{ background: #161b22; border-bottom: 1px solid #30363d; padding: 16px 24px; display: flex; align-items: center; gap: 12px; }}
  .header h1 {{ font-size: 20px; font-weight: 600; }}
  .header .sub {{ color: #8b949e; font-size: 13px; margin-left: auto; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 16px; padding: 24px; }}
  .card {{ background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 20px; }}
  .card h2 {{ font-size: 14px; font-weight: 600; color: #8b949e; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 16px; }}
  .stat {{ font-size: 28px; font-weight: 700; color: #58a6ff; }}
  .stat-label {{ font-size: 12px; color: #8b949e; margin-top: 4px; }}
  table {{ width: 100%; border-collapse: collapse; font-size: 13px; }}
  th {{ text-align: left; padding: 8px; color: #8b949e; font-weight: 500; border-bottom: 1px solid #30363d; }}
  td {{ padding: 10px 8px; border-bottom: 1px solid #21262d; }}
  tr:last-child td {{ border-bottom: none; }}
  .badge {{ padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; }}
  .badge.paper {{ background: #1f3d2a; color: #3fb950; }}
  .badge.live {{ background: #3d1f1f; color: #f85149; }}
  .badge.buy {{ background: #1f3d2a; color: #3fb950; }}
  .badge.sell {{ background: #3d1f1f; color: #f85149; }}
  .ticker-chip {{ display: inline-block; background: #1f2937; border: 1px solid #374151; border-radius: 6px; padding: 4px 10px; margin: 3px; font-size: 12px; font-weight: 600; color: #58a6ff; }}
  .memory-box {{ font-size: 12px; color: #8b949e; line-height: 1.6; max-height: 200px; overflow-y: auto; white-space: pre-wrap; }}
  .full-width {{ grid-column: 1 / -1; }}
  .green {{ color: #3fb950; }}
  .red {{ color: #f85149; }}
  .stats-row {{ display: flex; gap: 24px; flex-wrap: wrap; }}
  .stat-box {{ flex: 1; min-width: 120px; }}
  .live-banner {{ background: #3d1f1f; border: 1px solid #f85149; color: #f85149; padding: 12px 24px; font-weight: 600; font-size: 14px; }}
  .paper-banner {{ background: #1f2d1f; border-bottom: 1px solid #3fb950; color: #3fb950; padding: 12px 24px; font-size: 13px; }}
</style>
</head>
<body>
<div class="header">
  <span style="font-size:24px">🦞</span>
  <h1>FinClaw Dashboard</h1>
  {mode_badge}
  <span class="sub">Auto-refreshes every 60s &nbsp;•&nbsp; {datetime.now().strftime("%b %d %Y %H:%M")}</span>
</div>
{mode_banner}
<div class="grid">

  <div class="card">
    <h2>Portfolio</h2>
    <div class="stats-row">
      <div class="stat-box">
        <div class="stat">{currency} {portfolio.get('cash', 0):,.2f}</div>
        <div class="stat-label">Cash Balance</div>
      </div>
      <div class="stat-box">
        <div class="stat">{len(portfolio.get('positions', []))}</div>
        <div class="stat-label">Open Positions</div>
      </div>
    </div>
  </div>

  <div class="card">
    <h2>Watchlist</h2>
    <div style="margin-top:4px">{watchlist_html}</div>
  </div>

  <div class="card full-width">
    <h2>Open Positions</h2>
    <table>
      <thead><tr><th>Ticker</th><th>Shares</th><th>Avg Cost</th><th>Current Price</th><th>P&L</th></tr></thead>
      <tbody>{positions_html}</tbody>
    </table>
  </div>

  <div class="card full-width">
    <h2>Trade History (last 20)</h2>
    <table>
      <thead><tr><th>Date</th><th>Ticker</th><th>Action</th><th>Shares</th><th>Price</th><th>Total</th></tr></thead>
      <tbody>{trades_html}</tbody>
    </table>
  </div>

  <div class="card">
    <h2>Alerts</h2>
    <div class="memory-box">{alerts}</div>
  </div>

  <div class="card">
    <h2>Today's Memory Log</h2>
    <div class="memory-box">{memory}</div>
  </div>

</div>
</body>
</html>"""

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        html = render_dashboard().encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", len(html))
        self.end_headers()
        self.wfile.write(html)

    def log_message(self, *args):
        pass

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    print(f"FinClaw Dashboard running at http://localhost:{port}")
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
