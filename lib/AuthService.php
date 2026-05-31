<?php

declare(strict_types=1);

final class AuthService
{
    public function __construct(private Database $db) {}

    public function registerOrUpdate(string $username, int $userId, string $password): array
    {
        $username = trim($username);
        if ($username === '' || $userId <= 0 || strlen($password) < 8) {
            throw new InvalidArgumentException('Invalid username, user_id, or password (min 8 chars)');
        }

        $pdo = $this->db->pdo();
        $now = gmdate('Y-m-d H:i:s');
        $hash = password_hash($password, PASSWORD_DEFAULT);

        $stmt = $pdo->prepare('SELECT username, user_id FROM user_accounts WHERE username = :u OR user_id = :uid');
        $stmt->execute([':u' => $username, ':uid' => $userId]);
        $existing = $stmt->fetch();

        if ($existing) {
            if ((int) $existing['user_id'] !== $userId) {
                throw new RuntimeException('Username or user_id conflict', 409);
            }
            $pdo->prepare(
                'UPDATE user_accounts SET password_hash = :hash, username = :u, updated_at = :now WHERE user_id = :uid'
            )->execute([':hash' => $hash, ':u' => $username, ':now' => $now, ':uid' => $userId]);

            return ['ok' => true, 'registered' => false, 'updated' => true, 'username' => $username];
        }

        $pdo->prepare(
            'INSERT INTO user_accounts (username, user_id, password_hash, created_at, updated_at)
             VALUES (:u, :uid, :hash, :now, :now)'
        )->execute([':u' => $username, ':uid' => $userId, ':hash' => $hash, ':now' => $now]);

        return ['ok' => true, 'registered' => true, 'updated' => false, 'username' => $username];
    }

    public function login(string $username, string $password): bool
    {
        $username = trim($username);
        $where = $this->db->sql()->usernameEquals(':u');
        $stmt = $this->db->pdo()->prepare(
            "SELECT username, password_hash FROM user_accounts WHERE {$where}"
        );
        $stmt->execute([':u' => $username]);
        $row = $stmt->fetch();
        if (!$row || !password_verify($password, $row['password_hash'])) {
            return false;
        }
        $this->db->pdo()->prepare('UPDATE user_accounts SET last_login = :now WHERE username = :u')
            ->execute([':now' => gmdate('Y-m-d H:i:s'), ':u' => $row['username']]);

        return true;
    }

    public function loginAdmin(string $password): bool
    {
        $expected = app_config('admin_password', '');
        if ($expected === '') {
            $expected = app_config('dashboard_password', '');
        }
        return $expected !== '' && hash_equals($expected, $password);
    }
}
