<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, X-API-Key');
    exit;
}

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, X-API-Key');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['error' => 'POST only'], 405);
}

require_api_key();

$raw = file_get_contents('php://input');
$data = json_decode($raw ?: '{}', true);
if (!is_array($data)) {
    json_response(['error' => 'Invalid JSON'], 400);
}

// Batch: { "events": [ {...}, {...} ] }
if (isset($data['events']) && is_array($data['events'])) {
    $ids = [];
    foreach ($data['events'] as $row) {
        if (!is_array($row)) {
            continue;
        }
        try {
            $result = app_events()->ingest($row);
            $ids[] = $result['id'] ?? null;
        } catch (Throwable $e) {
            json_response(['error' => $e->getMessage()], 400);
        }
    }
    json_response(['ok' => true, 'count' => count($ids), 'ids' => $ids]);
}

try {
    $result = app_events()->ingest($data);
    json_response($result);
} catch (Throwable $e) {
    json_response(['error' => $e->getMessage()], 400);
}
