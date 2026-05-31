<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
require_dashboard_auth();

$svc = app_events();
$days = max(1, min(90, (int) ($_GET['days'] ?? 7)));

json_response([
    'overview' => $svc->getOverviewStats(),
    'events_per_day' => $svc->getEventsPerDay($days),
    'purchases_by_rank' => $svc->getPurchasesByRank($days),
    'purchases_by_variant' => $svc->getPurchasesByVariant($days),
    'feature_toggles' => $svc->getFeatureToggles($days),
    'players' => $svc->getPlayers(),
    'sessions' => $svc->getSessions(40),
    'recent_events' => array_map(static function (array $row): array {
        $row['props'] = json_decode($row['props'] ?? '{}', true);
        return $row;
    }, $svc->getRecentEvents(60, $_GET['username'] ?? null, $_GET['event'] ?? null)),
]);
