<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Login · <?= htmlspecialchars(app_config('site_title', 'Analytics')) ?></title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700&family=Zen+Tokyo+Zoo&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/assets/css/theme.css">
</head>
<body class="login-page">
  <div class="login-card glass">
    <div class="login-badge">✦</div>
    <h1><?= htmlspecialchars(app_config('site_title', 'Analytics')) ?></h1>
    <p class="muted">Dashboard access</p>
    <?php if (!empty($GLOBALS['login_error'])): ?>
      <p class="error"><?= htmlspecialchars($GLOBALS['login_error']) ?></p>
    <?php endif; ?>
    <form method="post">
      <input type="password" name="dashboard_password" placeholder="Password" autofocus required>
      <button type="submit">Enter</button>
    </form>
  </div>
</body>
</html>
