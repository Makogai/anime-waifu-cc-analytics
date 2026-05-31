# Waifu Analytics Dashboard

PHP + SQLite analytics for the Roblox script. Host on **Coolify** with document root `public/`.

## Quick setup (Coolify)

1. Create a new **Application** → use the included **Dockerfile** (root: `dashboard/`).
2. Copy `config.example.php` → `config.php` and set:
   - `api_key` — long random string (same as in script)
   - `dashboard_password` — for web UI login
   - `discord_webhook` — for cron summaries
3. Mount a **persistent volume** on `storage/` (SQLite database).
4. Add **Scheduled Task** (cron):
   ```bash
   php /var/www/html/cron/discord_summary.php
   ```
   Every **30 minutes** (match `summary_interval_minutes` in config).

## API

**POST** `https://your-domain.com/api.php`

Headers:
- `Content-Type: application/json`
- `X-API-Key: your-api-key`

Body:
```json
{
  "event_name": "pack_purchase",
  "username": "PlayerName",
  "user_id": 123456,
  "place_id": 123,
  "job_id": "uuid",
  "session_id": "1700000000_123456",
  "script_version": "1.5",
  "props": {
    "rank": "Beyond",
    "variant": "Solaris",
    "slot": 2,
    "price": "1.2M"
  }
}
```

Batch:
```json
{
  "events": [ { "event_name": "..." }, { "event_name": "..." } ]
}
```

## Script wiring

Enable in the script **Analytics** tab, or set at top of `otherscript.lua`:

```lua
SaveFile.BackendUrl = "https://analytics.yourdomain.com"
SaveFile.BackendApiKey = "same-as-config-api_key"
SaveFile.BackendEnabled = true
```

Events logged automatically:
- `script_load` / `script_destroy` (session + uptime)
- `session_heartbeat` every 5 minutes
- `pack_purchase` on auto-buy

Discord summaries are sent by **server cron** — not the in-game 30 min buffer.

## Dashboard

Open `https://your-domain.com/` — login with `dashboard_password`.

- Activity charts (7/30 days)
- Purchases by rank / variant
- Player list + online status
- Session duration
- Live event feed

## Local test

```bash
cd dashboard
cp config.example.php config.php
php -S localhost:8080 -t public
```

Cron manually:
```bash
php cron/discord_summary.php
```
