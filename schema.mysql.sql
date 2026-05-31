-- Waifu Script Analytics (MySQL 8+)

CREATE TABLE IF NOT EXISTS events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_name VARCHAR(64) NOT NULL,
    username VARCHAR(64) NULL,
    user_id BIGINT NULL,
    place_id BIGINT NULL,
    job_id VARCHAR(64) NULL,
    session_id VARCHAR(128) NULL,
    script_version VARCHAR(32) NULL,
    props JSON NOT NULL,
    INDEX idx_events_created (created_at),
    INDEX idx_events_name (event_name),
    INDEX idx_events_username (username),
    INDEX idx_events_session (session_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS players (
    username VARCHAR(64) PRIMARY KEY,
    user_id BIGINT NULL,
    first_seen DATETIME NOT NULL,
    last_seen DATETIME NOT NULL,
    total_sessions INT NOT NULL DEFAULT 0,
    total_events INT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sessions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    session_id VARCHAR(128) NOT NULL UNIQUE,
    username VARCHAR(64) NOT NULL,
    user_id BIGINT NULL,
    started_at DATETIME NOT NULL,
    last_heartbeat DATETIME NULL,
    ended_at DATETIME NULL,
    script_version VARCHAR(32) NULL,
    uptime_sec INT NULL,
    INDEX idx_sessions_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS cron_state (
    `key` VARCHAR(64) PRIMARY KEY,
    value TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_accounts (
    username VARCHAR(64) PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    last_login DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
