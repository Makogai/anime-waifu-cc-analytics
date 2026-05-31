<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
}

$_SESSION = [];
session_destroy();

header('Location: /');
exit;
