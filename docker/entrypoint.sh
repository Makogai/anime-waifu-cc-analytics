#!/bin/bash
set -e

if [ ! -f /var/www/html/config.php ]; then
    cp /var/www/html/config.example.php /var/www/html/config.php
fi

mkdir -p /var/www/html/storage
chown -R www-data:www-data /var/www/html/storage

exec apache2-foreground
