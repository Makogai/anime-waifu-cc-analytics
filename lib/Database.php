<?php

declare(strict_types=1);

final class Database
{
    private PDO $pdo;
    private SqlDialect $sql;

    /** @param array<string, mixed> $config */
    public function __construct(array $config)
    {
        $driver = $config['db_driver'] ?? 'sqlite';
        $this->sql = new SqlDialect($driver);

        if ($driver === 'mysql') {
            $mysql = $config['mysql'] ?? [];
            $host = $mysql['host'] ?? '127.0.0.1';
            $port = (int) ($mysql['port'] ?? 3306);
            $dbname = $mysql['database'] ?? 'waifu_analytics';
            $user = $mysql['username'] ?? 'root';
            $pass = $mysql['password'] ?? '';
            $dsn = "mysql:host={$host};port={$port};dbname={$dbname};charset=utf8mb4";
            $this->pdo = new PDO($dsn, $user, $pass, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ]);
            $this->migrate('schema.mysql.sql');
            return;
        }

        $path = $config['database_path'] ?? (__DIR__ . '/../storage/analytics.sqlite');
        $dir = dirname($path);
        if (!is_dir($dir)) {
            mkdir($dir, 0775, true);
        }
        $this->pdo = new PDO('sqlite:' . $path, null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
        $this->pdo->exec('PRAGMA journal_mode = WAL');
        $this->migrate('schema.sql');
    }

    public function pdo(): PDO
    {
        return $this->pdo;
    }

    public function sql(): SqlDialect
    {
        return $this->sql;
    }

    private function migrate(string $schemaFile): void
    {
        $schema = file_get_contents(dirname(__DIR__) . '/' . $schemaFile);
        if ($schema === false) {
            return;
        }
        if ($this->sql->isMysql()) {
            foreach (array_filter(array_map('trim', explode(';', $schema))) as $statement) {
                if ($statement !== '') {
                    $this->pdo->exec($statement);
                }
            }
            return;
        }
        $this->pdo->exec($schema);
    }
}
