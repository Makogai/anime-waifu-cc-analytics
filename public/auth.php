<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
require_api_key();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['error' => 'POST only'], 405);
}

$raw = file_get_contents('php://input');
$data = json_decode($raw ?: '{}', true);
if (!is_array($data)) {
    json_response(['error' => 'Invalid JSON'], 400);
}

$username = trim((string) ($data['username'] ?? ''));
$userId = (int) ($data['user_id'] ?? 0);
$password = (string) ($data['password'] ?? '');

try {
    $result = app_auth()->registerOrUpdate($username, $userId, $password);
    json_response($result);
} catch (InvalidArgumentException $e) {
    json_response(['error' => $e->getMessage()], 400);
} catch (RuntimeException $e) {
    json_response(['error' => $e->getMessage()], (int) ($e->getCode() ?: 409));
} catch (Throwable $e) {
    json_response(['error' => 'Registration failed'], 500);
}
