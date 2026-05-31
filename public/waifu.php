<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';

$key = trim((string) ($_GET['key'] ?? $_SERVER['HTTP_X_API_KEY'] ?? ''));
$expected = trim((string) app_config('api_key', ''));

if ($expected === '' || $expected === 'change-me-to-a-long-random-string') {
    http_response_code(503);
    header('Content-Type: text/plain');
    echo 'Server API_KEY not configured';
    exit;
}

if ($key === '' || !hash_equals($expected, $key)) {
    http_response_code(403);
    header('Content-Type: text/plain');
    echo 'Forbidden — pass ?key=YOUR_API_KEY or X-API-Key header';
    exit;
}

$scriptPath = dirname(__DIR__) . '/script/waifu.lua';
if (!is_readable($scriptPath)) {
    http_response_code(404);
    header('Content-Type: text/plain');
    echo 'Script file missing on server — run sync-waifu.py from repo root';
    exit;
}

header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: no-store');
readfile($scriptPath);
