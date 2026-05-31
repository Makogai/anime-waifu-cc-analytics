-- Waifu Script Analytics (SQLite)
-- Auto-applied on first request if tables missing.

CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    event_name TEXT NOT NULL,
    username TEXT,
    user_id INTEGER,
    place_id INTEGER,
    job_id TEXT,
    session_id TEXT,
    script_version TEXT,
    props TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS players (
    username TEXT PRIMARY KEY,
    user_id INTEGER,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    total_sessions INTEGER NOT NULL DEFAULT 0,
    total_events INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL,
    user_id INTEGER,
    started_at TEXT NOT NULL,
    last_heartbeat TEXT,
    ended_at TEXT,
    script_version TEXT,
    uptime_sec INTEGER
);

CREATE TABLE IF NOT EXISTS cron_state (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_accounts (
    username TEXT PRIMARY KEY COLLATE NOCASE,
    user_id INTEGER NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    last_login TEXT
);

CREATE INDEX IF NOT EXISTS idx_events_created ON events(created_at);
CREATE INDEX IF NOT EXISTS idx_events_name ON events(event_name);
CREATE INDEX IF NOT EXISTS idx_events_username ON events(username);
CREATE INDEX IF NOT EXISTS idx_events_session ON events(session_id);
CREATE INDEX IF NOT EXISTS idx_sessions_username ON sessions(username);
