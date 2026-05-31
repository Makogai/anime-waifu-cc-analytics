FROM php:8.2-apache-bookworm

RUN docker-php-ext-install pdo_sqlite pdo_mysql \
    && a2enmod rewrite \
    && sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/*.conf \
    && sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/apache2.conf

WORKDIR /var/www/html

COPY . /var/www/html/

RUN mkdir -p storage \
    && chown -R www-data:www-data storage \
    && chmod 775 storage
