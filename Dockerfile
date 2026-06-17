FROM php:8.1-apache

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_MEMORY_LIMIT=-1
ENV APACHE_DOCUMENT_ROOT=/var/www/html/web

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    libpq-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libonig-dev \
    libwebp-dev \
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
        exif \
    && a2enmod rewrite headers expires \
    && sed -ri \
        -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
        /etc/apache2/sites-available/*.conf \
    && sed -ri \
        -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' \
        /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && rm -rf /var/lib/apt/lists/*

# PHP configuration
COPY php.ini /usr/local/etc/php/conf.d/opigno.ini

WORKDIR /var/www/html

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- \
      --install-dir=/usr/local/bin \
      --filename=composer \
    && composer --version

# Composer global settings for Drupal/Opigno plugins
RUN composer config --global audit.block-insecure false || true \
    && composer config --global allow-plugins.composer/installers true \
    && composer config --global allow-plugins.drupal/core-composer-scaffold true \
    && composer config --global allow-plugins.cweagans/composer-patches true \
    && composer config --global allow-plugins.wikimedia/composer-merge-plugin true \
    && composer config --global allow-plugins.mglaman/composer-drupal-lenient true

# Download Opigno project WITHOUT installing dependencies first
RUN composer create-project opigno/opigno-composer:3.2.7 /tmp/opigno \
      --stability stable \
      --no-install \
      --no-interaction \
      --no-progress

# Move project to Apache directory
RUN cp -a /tmp/opigno/. /var/www/html/ \
    && rm -rf /tmp/opigno

WORKDIR /var/www/html

# Project-level Composer settings
RUN composer config audit.block-insecure false || true \
    && composer config allow-plugins.composer/installers true \
    && composer config allow-plugins.drupal/core-composer-scaffold true \
    && composer config allow-plugins.cweagans/composer-patches true \
    && composer config allow-plugins.wikimedia/composer-merge-plugin true \
    && composer config allow-plugins.mglaman/composer-drupal-lenient true

# Install Opigno dependencies
RUN composer install \
      --no-interaction \
      --no-progress \
      --no-audit \
      --with-all-dependencies

# Ensure Drush is available
RUN composer require drush/drush:^12 \
      --with-all-dependencies \
      --no-interaction \
      --no-progress \
      --no-audit

# Copy startup script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Prepare Drupal writable folders
RUN mkdir -p /var/www/html/web/sites/default/files /var/www/html/private \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/web/sites/default/files /var/www/html/private

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["apache2-foreground"]
