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
    <div class="login-badge">🌸</div>
    <h1><?= htmlspecialchars(app_config('site_title', 'Analytics')) ?></h1>
    <p class="muted">Log in with your Roblox username + script password</p>
    <p class="muted small">Password is created automatically the first time you enable backend logging in the script.</p>
    <?php if (!empty($GLOBALS['login_error'])): ?>
      <p class="error"><?= htmlspecialchars($GLOBALS['login_error']) ?></p>
    <?php endif; ?>
    <form method="post" class="login-form">
      <input type="text" name="username" placeholder="Roblox username" autocomplete="username" autofocus required>
      <input type="password" name="password" placeholder="Dashboard password" autocomplete="current-password" required>
      <button type="submit">Sign in</button>
    </form>
    <p class="muted small admin-hint">Admin: username <code>_admin</code> + admin password from config</p>
  </div>
</body>
</html>
