<?php

declare(strict_types=1);

$configPath = dirname(__DIR__) . '/config.php';
if (!is_file($configPath)) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Missing config.php — copy config.example.php']);
    exit;
}

$config = require $configPath;
date_default_timezone_set($config['timezone'] ?? 'UTC');

require_once __DIR__ . '/Database.php';
require_once __DIR__ . '/EventService.php';
require_once __DIR__ . '/DiscordNotifier.php';

function app_config(string $key, mixed $default = null): mixed
{
    global $config;
    return $config[$key] ?? $default;
}

function app_db(): Database
{
    static $db = null;
    if ($db === null) {
        $db = new Database(app_config('database_path'));
    }
    return $db;
}

function app_events(): EventService
{
    static $svc = null;
    if ($svc === null) {
        $svc = new EventService(app_db());
    }
    return $svc;
}

function json_response(array $data, int $code = 200): void
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function require_api_key(): void
{
    $expected = app_config('api_key', '');
    $provided = $_SERVER['HTTP_X_API_KEY'] ?? '';
    if ($expected === '' || !hash_equals($expected, $provided)) {
        json_response(['error' => 'Unauthorized'], 401);
    }
}

function require_dashboard_auth(): void
{
    $password = app_config('dashboard_password', '');
    if ($password === '') {
        return;
    }
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }
    if (!empty($_SESSION['dashboard_auth'])) {
        return;
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['dashboard_password'])) {
        if (hash_equals($password, (string) $_POST['dashboard_password'])) {
            $_SESSION['dashboard_auth'] = true;
            header('Location: ' . strtok($_SERVER['REQUEST_URI'], '?'));
            exit;
        }
        $GLOBALS['login_error'] = 'Wrong password';
    }
    require __DIR__ . '/../templates/login.php';
    exit;
}
