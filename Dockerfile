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

# Important:
# Some Composer versions may fail on audit.ignore syntax.
# This disables Composer blocking insecure packages during build.
RUN composer config --global audit.block-insecure false || true

# Install Opigno LMS Community 3.2.7
RUN composer create-project opigno/opigno-composer:3.2.7 /tmp/opigno \
      --stability stable \
      --no-interaction \
      --no-progress \
      -vvv

# Copy Opigno project into Apache directory
RUN cp -a /tmp/opigno/. /var/www/html/ \
    && rm -rf /tmp/opigno

# Install Drush
RUN cd /var/www/html \
    && composer require drush/drush:^12 \
      --with-all-dependencies \
      --no-interaction \
      --no-progress

# Copy startup script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Prepare Drupal writable folders
RUN mkdir -p /var/www/html/web/sites/default/files /var/www/html/private \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/web/sites/default/files /var/www/html/private

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["apache2-foreground"]
