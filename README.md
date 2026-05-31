# Waifu Analytics Dashboard

PHP analytics for the Roblox script. Host on **Coolify** with document root `public/`.

## SQLite vs MySQL — which to use?

| | **SQLite + volume** | **MySQL (recommended on Coolify)** |
|--|---------------------|-------------------------------------|
| Setup | Easiest locally | One MySQL service in Coolify |
| Persistence | You must add a volume mount | Automatic (DB is separate) |
| Backups | Copy one `.sqlite` file | Coolify / mysqldump |
| Best for | Local dev, single tiny deploy | Production, Coolify, many events |

**Recommendation:** use **MySQL on Coolify** if you are deploying there. Use **SQLite** for `php -S localhost:8080` on your PC.

---

## Option A — MySQL on Coolify (recommended)

### 1. Create MySQL in Coolify

1. **+ Add** → **Database** → **MySQL** (8.x).
2. Set database name e.g. `waifu_analytics`, user + password.
3. Deploy the database.

### 2. Deploy the dashboard app

1. **+ Add** → **Application** → your repo.
2. **Base Directory:** leave **empty** if this repo *is* the dashboard folder (you ran `git init` inside `dashboard/`). Use `dashboard/` only when deploying from the parent monorepo.
3. Build: **Dockerfile** (included).
4. **Ports Exposes:** **80** (required — default 3000 causes **502 Bad Gateway**).
5. **Environment variables** (or link MySQL service — Coolify fills these):

```env
DB_DRIVER=mysql
MYSQL_HOST=<mysql service internal hostname>
MYSQL_PORT=3306
MYSQL_DATABASE=waifu_analytics
MYSQL_USER=waifu
MYSQL_PASSWORD=<your password>
```

### 3. Config

`config.php` is optional in Git — the container copies `config.example.php` on startup if missing. All secrets can come from **environment variables** (see `config.example.php`).

Tables are created automatically on first request (`schema.mysql.sql`).

### 4. Verify deploy

1. Open `https://your-domain/health.php` — should print `ok`.
2. Open `/` — login page (admin: username `_admin`, password from `ADMIN_PASSWORD`).

### 5. Cron (Discord summaries)

Scheduled Task every 30 min:

```bash
php /var/www/html/cron/discord_summary.php
```

---

## Option B — SQLite + volume mount on Coolify

Without a volume, **every redeploy wipes your analytics**.

### Steps

1. Deploy app (Dockerfile). Base Directory empty if repo root is this folder.
2. Open your application → **Storages** (or **Persistent Storage** / **Volumes**).
3. **Add Volume**:
   - **Container path:** `/var/www/html/storage`
   - **Name:** e.g. `waifu-analytics-data`
4. Redeploy.

In `config.php`:

```php
'db_driver' => 'sqlite',
'database_path' => __DIR__ . '/storage/analytics.sqlite',
```

### docker-compose (local / VPS)

Already configured:

```yaml
volumes:
  - waifu_data:/var/www/html/storage
```

Run: `docker compose up -d` from `dashboard/`.

---

## Quick local test (SQLite)

```bash
cd dashboard
cp config.example.php config.php
php -S localhost:8080 -t public
```

---

## API

**POST** `https://your-domain.com/api.php`

Headers: `Content-Type: application/json`, `X-API-Key: your-key`

See previous sections in this file for payload examples.

---

## Dashboard login

- **Players:** Roblox username + password from script (`Analytics` tab → Show dashboard login).
- **Admin:** username `_admin` + `admin_password` in config (sees all players).

---

## Script wiring

Analytics tab → Backend URL + API key → Enable backend logging.

Events: purchases, rerolls, cash collect, tokens, pack open/place, server hop, toggles, sessions.

Discord summaries: server cron, not in-game buffer.

---

## Troubleshooting 502 Bad Gateway

A **502** means Coolify’s proxy cannot reach your container — the deploy can still show “success.”

| Check | Fix |
|-------|-----|
| **Port** | **Ports Exposes** = `80` (not 3000) |
| **Base Directory** | Empty if you pushed from inside `dashboard/` |
| **Health** | Visit `/health.php` — `ok` = Apache is up |
| **Logs** | Coolify → your app → **Logs** — look for Apache/PHP errors |
| **MySQL** | Set `DB_DRIVER=mysql` + linked MySQL env vars; wrong host causes 500 on pages, not usually 502 |

After changing port or Dockerfile, **redeploy** (rebuild if Dockerfile changed).
