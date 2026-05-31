#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Run every 10–30 minutes via Coolify cron:
 * php /var/www/html/../cron/discord_summary.php
 */

require_once dirname(__DIR__) . '/lib/bootstrap.php';

$intervalMin = (int) app_config('summary_interval_minutes', 30);
$svc = app_events();
$notifier = new DiscordNotifier((string) app_config('discord_webhook', ''));

$key = 'discord_last_summary_at';
$last = $svc->getCronState($key);
$since = $last ?: gmdate('Y-m-d H:i:s', time() - ($intervalMin * 60));

$rows = $svc->getPurchasesSince($since);
$byPlayer = [];

foreach ($rows as $row) {
    $user = $row['username'] ?: 'Unknown';
    $props = json_decode($row['props'] ?? '{}', true) ?: [];
    $rank = $props['rank'] ?? '?';
    $variant = $props['variant'] ?? '?';
    $slot = $props['slot'] ?? '?';
    $price = $props['price'] ?? null;
    $line = "{$rank} · {$variant} (slot {$slot})";
    if ($price) {
        $line .= " — {$price}";
    }
    $byPlayer[$user] ??= [];
    $byPlayer[$user][] = $line;
}

$now = gmdate('Y-m-d H:i:s');
if ($notifier->isConfigured()) {
    $ok = $notifier->sendSummary($byPlayer, $intervalMin, $since . ' → ' . $now);
    echo $ok ? "Discord summary sent (" . count($rows) . " purchases)\n" : "Discord send failed\n";
} else {
    echo "Discord webhook not configured — skipped\n";
}

$svc->setCronState($key, $now);
