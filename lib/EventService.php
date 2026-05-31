<?php

declare(strict_types=1);

final class EventService
{
    public function __construct(private Database $db) {}

    public function ingest(array $payload): array
    {
        $eventName = trim((string) ($payload['event_name'] ?? ''));
        if ($eventName === '') {
            throw new InvalidArgumentException('event_name required');
        }

        $username = isset($payload['username']) ? trim((string) $payload['username']) : null;
        $userId = isset($payload['user_id']) ? (int) $payload['user_id'] : null;
        $placeId = isset($payload['place_id']) ? (int) $payload['place_id'] : null;
        $jobId = isset($payload['job_id']) ? (string) $payload['job_id'] : null;
        $sessionId = isset($payload['session_id']) ? (string) $payload['session_id'] : null;
        $scriptVersion = isset($payload['script_version']) ? (string) $payload['script_version'] : null;
        $props = $payload['props'] ?? [];
        if (!is_array($props)) {
            $props = [];
        }
        if ($sessionId && empty($props['session_id'])) {
            $props['session_id'] = $sessionId;
        }

        $propsJson = json_encode($props, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($propsJson === false) {
            $propsJson = '{}';
        }

        $now = gmdate('Y-m-d H:i:s');
        $pdo = $this->db->pdo();

        $pdo->beginTransaction();
        try {
            if ($username) {
                $this->upsertPlayer($username, $userId, $now);
            }

            if ($sessionId && $username) {
                $this->touchSession($eventName, $sessionId, $username, $userId, $scriptVersion, $now, $props);
            }

            $stmt = $pdo->prepare(
                'INSERT INTO events (created_at, event_name, username, user_id, place_id, job_id, session_id, script_version, props)
                 VALUES (:created_at, :event_name, :username, :user_id, :place_id, :job_id, :session_id, :script_version, :props)'
            );
            $stmt->execute([
                ':created_at' => $now,
                ':event_name' => $eventName,
                ':username' => $username,
                ':user_id' => $userId,
                ':place_id' => $placeId,
                ':job_id' => $jobId,
                ':session_id' => $sessionId,
                ':script_version' => $scriptVersion,
                ':props' => $propsJson,
            ]);

            if ($username) {
                $pdo->prepare('UPDATE players SET total_events = total_events + 1, last_seen = :now WHERE username = :u')
                    ->execute([':now' => $now, ':u' => $username]);
            }

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }

        return ['ok' => true, 'id' => (int) $pdo->lastInsertId()];
    }

    private function upsertPlayer(string $username, ?int $userId, string $now): void
    {
        $pdo = $this->db->pdo();
        $exists = $pdo->prepare('SELECT username FROM players WHERE username = :u');
        $exists->execute([':u' => $username]);
        if ($exists->fetch()) {
            $pdo->prepare('UPDATE players SET last_seen = :now, user_id = COALESCE(:uid, user_id) WHERE username = :u')
                ->execute([':now' => $now, ':uid' => $userId, ':u' => $username]);
            return;
        }
        $pdo->prepare(
            'INSERT INTO players (username, user_id, first_seen, last_seen, total_sessions, total_events)
             VALUES (:u, :uid, :now, :now, 0, 0)'
        )->execute([':u' => $username, ':uid' => $userId, ':now' => $now]);
    }

    private function touchSession(
        string $eventName,
        string $sessionId,
        string $username,
        ?int $userId,
        ?string $scriptVersion,
        string $now,
        array $props
    ): void {
        $pdo = $this->db->pdo();
        $row = $pdo->prepare('SELECT id, started_at FROM sessions WHERE session_id = :sid');
        $row->execute([':sid' => $sessionId]);
        $existing = $row->fetch();

        if ($eventName === 'script_load') {
            if (!$existing) {
                $pdo->prepare(
                    'INSERT INTO sessions (session_id, username, user_id, started_at, last_heartbeat, script_version)
                     VALUES (:sid, :u, :uid, :now, :now, :ver)'
                )->execute([
                    ':sid' => $sessionId,
                    ':u' => $username,
                    ':uid' => $userId,
                    ':now' => $now,
                    ':ver' => $scriptVersion,
                ]);
                $pdo->prepare('UPDATE players SET total_sessions = total_sessions + 1 WHERE username = :u')
                    ->execute([':u' => $username]);
            } else {
                $pdo->prepare('UPDATE sessions SET last_heartbeat = :now WHERE session_id = :sid')
                    ->execute([':now' => $now, ':sid' => $sessionId]);
            }
            return;
        }

        if ($eventName === 'session_heartbeat' || $eventName === 'feature_toggle' || $eventName === 'pack_purchase') {
            if ($existing) {
                $pdo->prepare('UPDATE sessions SET last_heartbeat = :now WHERE session_id = :sid')
                    ->execute([':now' => $now, ':sid' => $sessionId]);
            }
        }

        if ($eventName === 'script_destroy') {
            $uptime = isset($props['uptime_sec']) ? (int) $props['uptime_sec'] : null;
            if ($existing && $uptime === null) {
                $started = strtotime($existing['started_at'] . ' UTC');
                $uptime = $started ? max(0, time() - $started) : null;
            }
            if ($existing) {
                $pdo->prepare(
                    'UPDATE sessions SET ended_at = :now, last_heartbeat = :now, uptime_sec = COALESCE(:up, uptime_sec)
                     WHERE session_id = :sid'
                )->execute([':now' => $now, ':up' => $uptime, ':sid' => $sessionId]);
            }
        }
    }

    private function userScope(?string $scopeUser, string $column = 'username'): array
    {
        if ($scopeUser === null || $scopeUser === '') {
            return ['', []];
        }

        return [" AND {$column} = :scope_user", [':scope_user' => $scopeUser]];
    }

    public function getOverviewStats(TimeRange $range, ?string $scopeUser = null): array
    {
        $pdo = $this->db->pdo();
        $sql = $this->db->sql();
        $since = $range->sinceClause($sql);
        [$userSql, $userParams] = $this->userScope($scopeUser);

        $count = static function (string $extra) use ($pdo, $userSql, $userParams): int {
            $stmt = $pdo->prepare("SELECT COUNT(*) FROM events WHERE 1=1 {$userSql} {$extra}");
            $stmt->execute($userParams);
            return (int) $stmt->fetchColumn();
        };

        $sessionSql = '';
        $sessionParams = [];
        if ($scopeUser) {
            $sessionSql = ' AND username = :scope_user';
            $sessionParams = [':scope_user' => $scopeUser];
        }

        $online = $sql->onlineSince();
        $stmtSessions = $pdo->prepare(
            "SELECT COUNT(*) FROM sessions
             WHERE ended_at IS NULL AND last_heartbeat >= {$online} {$sessionSql}"
        );
        $stmtSessions->execute($sessionParams);

        $stmtUptime = $pdo->prepare(
            "SELECT AVG(uptime_sec) FROM sessions WHERE uptime_sec IS NOT NULL {$sessionSql}"
        );
        $stmtUptime->execute($sessionParams);

        $playerCount = $scopeUser ? 1 : (int) $pdo->query('SELECT COUNT(*) FROM players')->fetchColumn();

        return [
            'range_key' => $range->key,
            'range_label' => $range->label,
            'total_events' => $count(''),
            'total_players' => $playerCount,
            'period_events' => $count("AND created_at >= {$since}"),
            'period_purchases' => $count("AND event_name = 'pack_purchase' AND created_at >= {$since}"),
            'active_sessions' => (int) $stmtSessions->fetchColumn(),
            'avg_uptime_min' => round((float) $stmtUptime->fetchColumn() / 60, 1),
        ];
    }

    public function getEventsOverTime(TimeRange $range, ?string $scopeUser = null): array
    {
        $pdo = $this->db->pdo();
        $sql = $this->db->sql();
        $since = $range->sinceClause($sql);
        $bucket = $sql->bucket($range->bucketSql);
        [$userSql, $userParams] = $this->userScope($scopeUser);
        $query = "SELECT {$bucket} AS bucket, COUNT(*) AS total
                FROM events
                WHERE created_at >= {$since} {$userSql}
                GROUP BY bucket ORDER BY bucket ASC";
        $stmt = $pdo->prepare($query);
        $stmt->execute($userParams);
        return $stmt->fetchAll();
    }

    public function getPurchasesByRank(TimeRange $range, ?string $scopeUser = null): array
    {
        $sql = $this->db->sql();
        $since = $range->sinceClause($sql);
        [$userSql, $userParams] = $this->userScope($scopeUser);
        $rank = $sql->jsonExtract('props', '$.rank');
        $query = "SELECT {$rank} AS rank, COUNT(*) AS total
             FROM events
             WHERE event_name = 'pack_purchase'
               AND created_at >= {$since}
               AND {$rank} IS NOT NULL {$userSql}
             GROUP BY rank ORDER BY total DESC LIMIT 12";
        $stmt = $this->db->pdo()->prepare($query);
        $stmt->execute($userParams);
        return $stmt->fetchAll();
    }

    public function getPurchasesByVariant(TimeRange $range, ?string $scopeUser = null): array
    {
        $sql = $this->db->sql();
        $since = $range->sinceClause($sql);
        [$userSql, $userParams] = $this->userScope($scopeUser);
        $variant = $sql->jsonExtract('props', '$.variant');
        $query = "SELECT {$variant} AS variant, COUNT(*) AS total
             FROM events
             WHERE event_name = 'pack_purchase'
               AND created_at >= {$since}
               AND {$variant} IS NOT NULL {$userSql}
             GROUP BY variant ORDER BY total DESC";
        $stmt = $this->db->pdo()->prepare($query);
        $stmt->execute($userParams);
        return $stmt->fetchAll();
    }

    public function getRecentEvents(
        TimeRange $range,
        int $limit = 50,
        ?string $username = null,
        ?string $eventName = null,
        ?string $scopeUser = null
    ): array {
        $pdo = $this->db->pdo();
        $since = $range->sinceClause($this->db->sql());
        $sql = "SELECT * FROM events WHERE created_at >= $since";
        $params = [];
        $filterUser = $scopeUser ?? $username;
        if ($filterUser) {
            $sql .= ' AND username = :u';
            $params[':u'] = $filterUser;
        }
        if ($eventName) {
            $sql .= ' AND event_name = :e';
            $params[':e'] = $eventName;
        }
        $sql .= ' ORDER BY created_at DESC LIMIT ' . (int) $limit;
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function getPlayers(?string $scopeUser = null): array
    {
        $online = $this->db->sql()->onlineSince();
        if ($scopeUser) {
            $stmt = $this->db->pdo()->prepare(
                "SELECT p.*,
                    (SELECT COUNT(*) FROM sessions s WHERE s.username = p.username AND s.ended_at IS NULL
                        AND s.last_heartbeat >= {$online}) AS online
                 FROM players p WHERE p.username = :u LIMIT 1"
            );
            $stmt->execute([':u' => $scopeUser]);
            return $stmt->fetchAll();
        }

        return $this->db->pdo()->query(
            "SELECT p.*,
                (SELECT COUNT(*) FROM sessions s WHERE s.username = p.username AND s.ended_at IS NULL
                    AND s.last_heartbeat >= {$online}) AS online
             FROM players p ORDER BY p.last_seen DESC LIMIT 100"
        )->fetchAll();
    }

    public function getSessions(TimeRange $range, int $limit = 30, ?string $scopeUser = null): array
    {
        $since = $range->sinceClause($this->db->sql());
        [$userSql, $userParams] = $this->userScope($scopeUser, 'username');
        $sql = "SELECT * FROM sessions
             WHERE COALESCE(started_at, last_heartbeat) >= $since {$userSql}
             ORDER BY COALESCE(ended_at, last_heartbeat, started_at) DESC
             LIMIT :lim";
        $stmt = $this->db->pdo()->prepare($sql);
        foreach ($userParams as $k => $v) {
            $stmt->bindValue($k, $v);
        }
        $stmt->bindValue(':lim', $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function getActionCounts(TimeRange $range, ?string $scopeUser = null): array
    {
        $since = $range->sinceClause($this->db->sql());
        [$userSql, $userParams] = $this->userScope($scopeUser);
        $sql = "SELECT event_name, COUNT(*) AS total
             FROM events
             WHERE created_at >= $since {$userSql}
             GROUP BY event_name
             ORDER BY total DESC";
        $stmt = $this->db->pdo()->prepare($sql);
        $stmt->execute($userParams);
        return $stmt->fetchAll();
    }

    public function getPurchasesSince(string $sinceUtc): array
    {
        $stmt = $this->db->pdo()->prepare(
            "SELECT username, props, created_at FROM events
             WHERE event_name = 'pack_purchase' AND created_at > :since
             ORDER BY created_at ASC"
        );
        $stmt->execute([':since' => $sinceUtc]);
        return $stmt->fetchAll();
    }

    public function getCronState(string $key): ?string
    {
        $stmt = $this->db->pdo()->prepare('SELECT value FROM cron_state WHERE key = :k');
        $stmt->execute([':k' => $key]);
        $v = $stmt->fetchColumn();
        return $v === false ? null : (string) $v;
    }

    public function setCronState(string $key, string $value): void
    {
        $this->db->pdo()->prepare($this->db->sql()->upsertCronState())
            ->execute([':k' => $key, ':v' => $value]);
    }

    public function getFeatureToggles(TimeRange $range, ?string $scopeUser = null): array
    {
        $sql = $this->db->sql();
        $since = $range->sinceClause($sql);
        [$userSql, $userParams] = $this->userScope($scopeUser);
        $feature = $sql->jsonExtract('props', '$.feature');
        $enabled = $sql->jsonExtract('props', '$.enabled');
        $query = "SELECT {$feature} AS feature,
                    {$enabled} AS enabled,
                    COUNT(*) AS total
             FROM events
             WHERE event_name = 'feature_toggle'
               AND created_at >= {$since} {$userSql}
             GROUP BY feature, enabled
             ORDER BY total DESC LIMIT 20";
        $stmt = $this->db->pdo()->prepare($query);
        $stmt->execute($userParams);
        return $stmt->fetchAll();
    }
}
