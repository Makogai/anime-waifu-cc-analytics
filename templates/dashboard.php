<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= htmlspecialchars(app_config('site_title', 'Analytics')) ?></title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700&family=Zen+Tokyo+Zoo&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/assets/css/theme.css">
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js" defer></script>
  <script src="/assets/js/app.js" defer></script>
</head>
<body>
  <div class="bg-mesh"></div>
  <div class="petals" aria-hidden="true"></div>

  <header class="topbar glass">
    <div class="brand">
      <span class="brand-icon">🌸</span>
      <div>
        <h1><?= htmlspecialchars(app_config('site_title', 'Analytics')) ?></h1>
        <p><?= htmlspecialchars(app_config('site_subtitle', '')) ?></p>
      </div>
    </div>
    <div class="topbar-actions">
      <label class="range-select">
        Range
        <select id="daysRange">
          <option value="1">24 hours</option>
          <option value="7" selected>7 days</option>
          <option value="30">30 days</option>
        </select>
      </label>
      <button type="button" id="refreshBtn" class="btn ghost">Refresh</button>
    </div>
  </header>

  <main class="container">
    <section class="stats-grid" id="statsGrid">
      <article class="stat-card glass"><span class="label">Total events</span><strong id="statEvents">—</strong></article>
      <article class="stat-card glass accent"><span class="label">Events (24h)</span><strong id="statEvents24">—</strong></article>
      <article class="stat-card glass pink"><span class="label">Pack buys (24h)</span><strong id="statBuys24">—</strong></article>
      <article class="stat-card glass purple"><span class="label">Players</span><strong id="statPlayers">—</strong></article>
      <article class="stat-card glass"><span class="label">Online now</span><strong id="statOnline">—</strong></article>
      <article class="stat-card glass gold"><span class="label">Avg session</span><strong id="statUptime">—</strong></article>
    </section>

    <section class="charts-grid">
      <article class="panel glass">
        <h2>Activity</h2>
        <canvas id="activityChart"></canvas>
      </article>
      <article class="panel glass">
        <h2>Purchases by rank</h2>
        <canvas id="rankChart"></canvas>
      </article>
      <article class="panel glass">
        <h2>Purchases by variant</h2>
        <canvas id="variantChart"></canvas>
      </article>
    </section>

    <section class="split-grid">
      <article class="panel glass">
        <h2>Players</h2>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Player</th><th>Last seen</th><th>Sessions</th><th>Events</th><th></th></tr></thead>
            <tbody id="playersBody"></tbody>
          </table>
        </div>
      </article>
      <article class="panel glass">
        <h2>Recent sessions</h2>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Player</th><th>Started</th><th>Duration</th><th>Version</th></tr></thead>
            <tbody id="sessionsBody"></tbody>
          </table>
        </div>
      </article>
    </section>

    <section class="panel glass">
      <div class="panel-head">
        <h2>Live event feed</h2>
        <div class="filters">
          <input type="text" id="filterUser" placeholder="Filter player…">
          <select id="filterEvent">
            <option value="">All events</option>
            <option value="pack_purchase">pack_purchase</option>
            <option value="script_load">script_load</option>
            <option value="script_destroy">script_destroy</option>
            <option value="feature_toggle">feature_toggle</option>
            <option value="session_heartbeat">session_heartbeat</option>
          </select>
        </div>
      </div>
      <div class="table-wrap tall">
        <table>
          <thead><tr><th>Time (UTC)</th><th>Event</th><th>Player</th><th>Details</th></tr></thead>
          <tbody id="eventsBody"></tbody>
        </table>
      </div>
    </section>
  </main>

  <footer class="footer muted">Discord summaries run via cron · API at <code>/api.php</code></footer>
</body>
</html>
