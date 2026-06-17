FROM php:8.1-apache

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV APACHE_DOCUMENT_ROOT=/var/www/html/web

RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libpng-dev libjpeg-dev libfreetype6-dev \
    libzip-dev libicu-dev libxml2-dev libonig-dev libwebp-dev \
    postgresql-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install \
        pdo \
        pdo_pgsql \
        pgsql \
        gd \
        zip \
        intl \
        mbstring \
        opcache \
        bcmath \
        soap \
    && a2enmod rewrite headers expires \
    && sed -ri \
        -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
        /etc/apache2/sites-available/*.conf \
    && sed -ri \
        -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' \
        /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && rm -rf /var/lib/apt/lists/*

COPY php.ini /usr/local/etc/php/conf.d/opigno.ini

WORKDIR /var/www/html

RUN curl -sS https://getcomposer.org/installer | php -- \
      --install-dir=/usr/local/bin \
      --filename=composer

RUN composer create-project opigno/opigno-composer:3.2.7 /var/www/html --stability stable \
    && composer require drush/drush:^12 --with-all-dependencies

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN mkdir -p /var/www/html/web/sites/default/files /var/www/html/private \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/web/sites/default/files /var/www/html/private

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
