# 🛸 meme-signals

Public 24/7 meme-signal feed for **Robinhood Chain** — refreshed every 15 minutes by GitHub Actions (free, public repo = unlimited minutes).

- 📡 Latest scan: [`signals/latest.md`](signals/latest.md)
- 📂 History: [`signals/`](signals/)
- 🔔 Telegram alerts fire only on **STRONG** cluster signals (≥3 smart-money wallets, or ≥2 wallets with ≥$200 total)

## How it works

1. `gmgn-cli track smartmoney --chain robinhood` → cluster detection (≥2 distinct buyers per token)
2. `gmgn-cli market trending --chain robinhood --interval 1h` → top 10 by volume
3. Results committed here + Telegram alert on STRONG

## Secrets (owner only, via repo Settings → Secrets → Actions)

- `GMGN_API_KEY` — GMGN API key
- `TELEGRAM_BOT_TOKEN` — from @BotFather
- `TELEGRAM_CHAT_ID` — from @userinfobot

Manual trigger: Actions tab → `meme-signals` → Run workflow.
