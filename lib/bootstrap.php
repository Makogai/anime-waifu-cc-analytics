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
require_once __DIR__ . '/SqlDialect.php';
require_once __DIR__ . '/TimeRange.php';
require_once __DIR__ . '/AuthService.php';
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
        $db = new Database([
            'db_driver' => app_config('db_driver', 'sqlite'),
            'database_path' => app_config('database_path'),
            'mysql' => app_config('mysql', []),
        ]);
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

function app_auth(): AuthService
{
    static $svc = null;
    if ($svc === null) {
        $svc = new AuthService(app_db());
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

function dashboard_start_session(): void
{
    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }
}

function dashboard_is_admin(): bool
{
    dashboard_start_session();
    return !empty($_SESSION['dashboard_admin']);
}

function dashboard_username(): ?string
{
    dashboard_start_session();
    if (dashboard_is_admin()) {
        return null;
    }
    $user = $_SESSION['dashboard_username'] ?? null;
    return is_string($user) && $user !== '' ? $user : null;
}

function dashboard_scope_username(): ?string
{
    dashboard_start_session();
    if (!empty($_SESSION['dashboard_auth'])) {
        return dashboard_is_admin() ? null : dashboard_username();
    }
    return null;
}

function require_dashboard_auth(): void
{
    dashboard_start_session();

    if (!empty($_SESSION['dashboard_auth'])) {
        return;
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $username = trim((string) ($_POST['username'] ?? ''));
        $password = (string) ($_POST['password'] ?? '');

        if ($username === '_admin' && app_auth()->loginAdmin($password)) {
            $_SESSION['dashboard_auth'] = true;
            $_SESSION['dashboard_admin'] = true;
            header('Location: ' . strtok($_SERVER['REQUEST_URI'], '?'));
            exit;
        }

        if ($username !== '' && app_auth()->login($username, $password)) {
            $_SESSION['dashboard_auth'] = true;
            $_SESSION['dashboard_admin'] = false;
            $_SESSION['dashboard_username'] = $username;
            header('Location: ' . strtok($_SERVER['REQUEST_URI'], '?'));
            exit;
        }

        $GLOBALS['login_error'] = 'Invalid username or password';
    }

    require __DIR__ . '/../templates/login.php';
    exit;
}
