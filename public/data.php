<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';
require_dashboard_auth();

$svc = app_events();
$scope = dashboard_scope_username();
$range = TimeRange::parseRequest(
    isset($_GET['range']) ? (string) $_GET['range'] : null,
    isset($_GET['days']) ? (int) $_GET['days'] : null,
);

$filterUser = isset($_GET['username']) ? trim((string) $_GET['username']) : null;
if ($scope !== null) {
    $filterUser = $scope;
}

json_response([
    'range' => [
        'key' => $range->key,
        'label' => $range->label,
    ],
    'viewer' => [
        'username' => dashboard_username(),
        'admin' => dashboard_is_admin(),
    ],
    'action_counts' => $svc->getActionCounts($range, $scope),
    'overview' => $svc->getOverviewStats($range, $scope),
    'events_over_time' => $svc->getEventsOverTime($range, $scope),
    'purchases_by_rank' => $svc->getPurchasesByRank($range, $scope),
    'purchases_by_variant' => $svc->getPurchasesByVariant($range, $scope),
    'feature_toggles' => $svc->getFeatureToggles($range, $scope),
    'players' => $svc->getPlayers($scope),
    'sessions' => $svc->getSessions($range, 40, $scope),
    'recent_events' => array_map(static function (array $row): array {
        $row['props'] = json_decode($row['props'] ?? '{}', true);
        return $row;
    }, $svc->getRecentEvents($range, 80, $filterUser, $_GET['event'] ?? null, $scope)),
]);
