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

1. **+ Add** → **Application** → your repo, **Base Directory** = `dashboard/`.
2. Build: **Dockerfile** (included).
3. **Environment variables** (or link MySQL service — Coolify fills these):

```env
DB_DRIVER=mysql
MYSQL_HOST=<mysql service internal hostname>
MYSQL_PORT=3306
MYSQL_DATABASE=waifu_analytics
MYSQL_USER=waifu
MYSQL_PASSWORD=<your password>
```

### 3. `config.php` on the server

Either bake `config.php` in the image, mount it, or use env — simplest is edit `config.php`:

```php
'db_driver' => getenv('DB_DRIVER') ?: 'mysql',
'mysql' => [
    'host' => getenv('MYSQL_HOST') ?: '127.0.0.1',
    'port' => (int) (getenv('MYSQL_PORT') ?: 3306),
    'database' => getenv('MYSQL_DATABASE') ?: 'waifu_analytics',
    'username' => getenv('MYSQL_USER') ?: 'waifu',
    'password' => getenv('MYSQL_PASSWORD') ?: '',
],
```

Tables are created automatically on first request (`schema.mysql.sql`).

### 4. Cron (Discord summaries)

Scheduled Task every 30 min:

```bash
php /var/www/html/cron/discord_summary.php
```

---

## Option B — SQLite + volume mount on Coolify

Without a volume, **every redeploy wipes your analytics**.

### Steps

1. Deploy app (Dockerfile, base dir `dashboard/`).
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
