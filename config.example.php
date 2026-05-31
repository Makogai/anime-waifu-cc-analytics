<?php
/**
 * Copy to config.php and fill in before deploying to Coolify.
 * MySQL env vars (optional): DB_DRIVER, MYSQL_HOST, MYSQL_PORT, MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD
 */

return [
    'api_key' => getenv('API_KEY') ?: 'change-me-to-a-long-random-string',
    'admin_password' => getenv('ADMIN_PASSWORD') ?: 'change-me-admin',
    'dashboard_password' => getenv('DASHBOARD_PASSWORD') ?: '',

    'db_driver' => getenv('DB_DRIVER') ?: 'sqlite',

    'database_path' => __DIR__ . '/storage/analytics.sqlite',

    'mysql' => [
        'host' => getenv('MYSQL_HOST') ?: '127.0.0.1',
        'port' => (int) (getenv('MYSQL_PORT') ?: 3306),
        'database' => getenv('MYSQL_DATABASE') ?: 'waifu_analytics',
        'username' => getenv('MYSQL_USER') ?: 'waifu',
        'password' => getenv('MYSQL_PASSWORD') ?: 'change-me',
    ],

    'discord_webhook' => getenv('DISCORD_WEBHOOK') ?: 'https://discord.com/api/webhooks/...',
    'summary_interval_minutes' => (int) (getenv('SUMMARY_INTERVAL_MINUTES') ?: 30),
    'timezone' => getenv('TIMEZONE') ?: 'UTC',
    'site_title' => 'Waifu Script Analytics',
    'site_subtitle' => 'Anime Viper · Roblox automation',
];
