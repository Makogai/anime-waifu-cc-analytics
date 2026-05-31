<?php

declare(strict_types=1);

final class TimeRange
{
    public function __construct(
        public readonly string $key,
        public readonly string $label,
        public readonly string $sqliteOffset,
        public readonly string $bucketSql,
        public readonly string $bucketLabel,
    ) {}

    public static function fromKey(string $key): self
    {
        return match ($key) {
            '10m' => new self('10m', 'Last 10 min', '-10 minutes', "%Y-%m-%d %H:%M", 'minute'),
            '30m' => new self('30m', 'Last 30 min', '-30 minutes', "%Y-%m-%d %H:%M", 'minute'),
            '1h' => new self('1h', 'Last 1 hour', '-1 hour', "%Y-%m-%d %H:%M", 'minute'),
            '24h' => new self('24h', 'Last 24 hours', '-1 day', "%Y-%m-%d %H:00", 'hour'),
            '7d' => new self('7d', 'Last 7 days', '-7 days', '%Y-%m-%d', 'day'),
            '30d' => new self('30d', 'Last 30 days', '-30 days', '%Y-%m-%d', 'day'),
            default => new self('7d', 'Last 7 days', '-7 days', '%Y-%m-%d', 'day'),
        };
    }

    /** @return list<self> */
    public static function all(): array
    {
        return array_map(static fn (string $k) => self::fromKey($k), ['10m', '30m', '1h', '24h', '7d', '30d']);
    }

    public static function parseRequest(?string $range, ?int $days): self
    {
        if ($range !== null && $range !== '') {
            return self::fromKey($range);
        }
        if ($days === 1) {
            return self::fromKey('24h');
        }
        if ($days === 30) {
            return self::fromKey('30d');
        }
        if ($days !== null && $days > 1) {
            return self::fromKey('7d');
        }
        return self::fromKey('7d');
    }

    public function sinceClause(SqlDialect $sql): string
    {
        return $sql->since($this->sqliteOffset);
    }
}
