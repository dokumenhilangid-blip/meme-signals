#!/bin/bash
# scan.sh — Robinhood Chain smart-money radar + trending → signals/*.md + Telegram alert.
# Runs in GitHub Actions every 15 min. Secrets via env (never hardcoded).
set -u
cd "$(dirname "$0")"

STAMP=$(date -u +%F-%H%M)
OUT="signals/${STAMP}.md"
LATEST="signals/latest.md"
mkdir -p signals

send_tg() {
  [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ] || return 0
  curl -s -m 10 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=$1" -d "parse_mode=Markdown" >/dev/null || true
}

{
  echo "# Signals ${STAMP} UTC"
  echo ""
} > "$OUT"

# ── 1. Smart money buys (Robinhood) → cluster detection ──
SM_RAW=$(gmgn-cli track smartmoney --chain robinhood --side buy --limit 50 --raw 2>/dev/null || echo '{"list":[]}')

CLUSTERS=$(echo "$SM_RAW" | python3 -c "
import json,sys
from collections import defaultdict
try:
    items = json.load(sys.stdin).get('list', [])
except Exception:
    items = []
groups = defaultdict(lambda: {'makers': set(), 'usd': 0.0, 'sym': '', 'n': 0})
for t in items:
    g = groups[t.get('base_address','?')]
    g['makers'].add(t.get('maker','?'))
    g['usd'] += float(t.get('amount_usd',0) or 0)
    g['sym'] = (t.get('base_token') or {}).get('symbol','?')
    g['n'] += 1
rows = []
for addr,g in groups.items():
    w = len(g['makers'])
    if w >= 2:
        lvl = 'STRONG' if (w>=3 or g['usd']>=200) else 'MEDIUM'
        rows.append((lvl, g['sym'], addr, w, g['n'], g['usd']))
rows.sort(key=lambda r: -r[5])
for lvl,sym,addr,w,n,usd in rows[:10]:
    print(f'{lvl} | {sym} | {w} wallets / {n} buys / \${usd:,.0f} | {addr}')
")

echo "## Smart-money clusters (Robinhood, last 50 buys)" >> "$OUT"
if [ -n "$CLUSTERS" ]; then
  echo '```' >> "$OUT"; echo "$CLUSTERS" >> "$OUT"; echo '```' >> "$OUT"
else
  echo "No cluster signals (no token with >=2 distinct buyers)." >> "$OUT"
fi
echo "" >> "$OUT"

# ── 2. Trending top 10 (Robinhood 1h) ──
TREND=$(gmgn-cli market trending --chain robinhood --interval 1h --order-by volume --limit 10 --raw 2>/dev/null \
  | python3 -c "
import json,sys
try:
    ranks = json.load(sys.stdin)['data']['rank']
except Exception:
    ranks = []
print('| # | Symbol | Price | MCap | Vol 1h | SM | Liq | Rug |')
print('|---|---|---|---|---|---|---|---|')
for i,t in enumerate(ranks[:10],1):
    print(f\"| {i} | {t.get('symbol','?')} | \${t.get('price',0):.8f} | \${(t.get('market_cap') or 0):,.0f} | \${(t.get('volume') or 0):,.0f} | {t.get('smart_degen_count',0)} | \${(t.get('liquidity') or 0):,.0f} | {t.get('rug_ratio','?')} |\")
" 2>/dev/null || echo "_trending fetch failed_")

echo "## Trending Robinhood 1h (by volume)" >> "$OUT"
echo "$TREND" >> "$OUT"

cp "$OUT" "$LATEST"

# ── 3. Telegram alert only on STRONG ──
if echo "$CLUSTERS" | grep -q '^STRONG'; then
  MSG=$(echo "$CLUSTERS" | grep '^STRONG' | head -5)
  send_tg "⚡ *STRONG signal* (${STAMP} UTC) — ${MSG} — https://github.com/dokumenhilangid-blip/meme-signals/blob/main/${OUT}"
fi

echo "Wrote $OUT"
