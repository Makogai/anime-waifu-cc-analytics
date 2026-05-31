<?php
/**
 * Copy to config.php and fill in before deploying to Coolify.
 */

return [
    // Random string — script sends this as header: X-API-Key
    'api_key' => 'mrharoldbaby',

    // Dashboard login (leave password empty to disable auth — not recommended)
    'dashboard_password' => 'mrharoldbaby',

    // SQLite path (must be writable)
    'database_path' => __DIR__ . '/storage/analytics.sqlite',

    // Discord webhook for cron summaries (global; covers all players)
    'discord_webhook' => 'https://discord.com/api/webhooks/1506698522102075453/Bnlr_1VrkwXgKXt6H3bW7uQT0RK1kq0mSZ2YWdqVZMbQZWp4JctfJ65aSgWxhOhS6oAf',

    // How often cron should summarize (minutes) — informational label in embed
    'summary_interval_minutes' => 30,

    // Timezone for dashboard dates
    'timezone' => 'UTC',

    // Script display name in UI
    'site_title' => 'Waifu Script Analytics',
    'site_subtitle' => 'Anime Viper · Roblox automation',
];
