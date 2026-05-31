<?php

declare(strict_types=1);

/** SQL helpers for SQLite vs MySQL */
final class SqlDialect
{
    public function __construct(private readonly string $driver = 'sqlite') {}

    public function isMysql(): bool
    {
        return $this->driver === 'mysql';
    }

    public function since(string $offset): string
    {
        if ($this->isMysql()) {
            if (preg_match('/^-(\d+)\s+(minute|minutes|hour|hours|day|days)$/', $offset, $m)) {
                $n = (int) $m[1];
                $unit = match ($m[2]) {
                    'minute', 'minutes' => 'MINUTE',
                    'hour', 'hours' => 'HOUR',
                    default => 'DAY',
                };
                return "DATE_SUB(UTC_TIMESTAMP(), INTERVAL {$n} {$unit})";
            }
        }

        return "datetime('now', '{$offset}')";
    }

    public function onlineSince(): string
    {
        return $this->since('-10 minutes');
    }

    public function bucket(string $fmt, string $column = 'created_at'): string
    {
        if ($this->isMysql()) {
            return match ($fmt) {
                '%Y-%m-%d %H:%M' => "DATE_FORMAT({$column}, '%Y-%m-%d %H:%i')",
                '%Y-%m-%d %H:00' => "DATE_FORMAT({$column}, '%Y-%m-%d %H:00')",
                '%Y-%m-%d' => "DATE({$column})",
                default => "DATE_FORMAT({$column}, '%Y-%m-%d')",
            };
        }

        return "strftime('{$fmt}', {$column})";
    }

    public function jsonExtract(string $column, string $jsonPath): string
    {
        if ($this->isMysql()) {
            return "JSON_UNQUOTE(JSON_EXTRACT({$column}, '{$jsonPath}'))";
        }

        return "json_extract({$column}, '{$jsonPath}')";
    }

    public function upsertCronState(): string
    {
        if ($this->isMysql()) {
            return 'INSERT INTO cron_state (`key`, value) VALUES (:k, :v)
                    ON DUPLICATE KEY UPDATE value = VALUES(value)';
        }

        return 'INSERT INTO cron_state (key, value) VALUES (:k, :v)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value';
    }

    public function usernameEquals(string $param = ':u'): string
    {
        if ($this->isMysql()) {
            return "username = {$param}";
        }

        return "username = {$param} COLLATE NOCASE";
    }
}
