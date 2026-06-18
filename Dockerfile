FROM php:8.2-apache

ARG COOLIFY_FQDN
ARG ADMIN_USER
ARG DB_HOST
ARG DB_NAME
ARG DB_PORT
ARG DB_USER
ARG DB_PASS
ARG SITE_NAME
ARG SERVICE_URL_OPIGNO
ARG SERVICE_FQDN_OPIGNOFROM php:8.2-apache

ARG COOLIFY_FQDN
ARG ADMIN_USER
ARG DB_HOST
ARG DB_NAME
ARG DB_PORT
ARG DB_USER
ARG DB_PASS
ARG SITE_NAME
ARG SERVICE_URL_OPIGNO
ARG SERVICE_FQDN_OPIGNO
ARG ADMIN_PASS
ARG ADMIN_EMAIL
ARG OPIGNO_VERSION
ARG TRUSTED_HOST

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_MEMORY_LIMIT=-1
ENV APACHE_DOCUMENT_ROOT=/var/www/html/web

RUN apt-get update && apt-get install -y 
git 
unzip 
curl 
ca-certificates 
libpq-dev 
libpng-dev 
libjpeg-dev 
libfreetype6-dev 
libzip-dev 
libicu-dev 
libxml2-dev 
libonig-dev 
libwebp-dev 
postgresql-client 
&& docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp 
&& docker-php-ext-install 
pdo 
pdo_pgsql 
pgsql 
gd 
zip 
intl 
mbstring 
opcache 
bcmath 
soap 
exif 
&& a2enmod rewrite headers expires 
&& echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf 
&& a2enconf servername 
&& sed -ri 
-e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' 
/etc/apache2/sites-available/*.conf 
&& sed -ri 
-e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' 
/etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf 
&& rm -rf /var/lib/apt/lists/*

COPY php.ini /usr/local/etc/php/conf.d/opigno.ini

RUN curl -sS https://getcomposer.org/installer | php -- 
--install-dir=/usr/local/bin 
--filename=composer 
&& composer --version

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /var/www/html

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["apache2-foreground"]

ARG ADMIN_PASS
ARG ADMIN_EMAIL
ARG OPIGNO_VERSION

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_MEMORY_LIMIT=-1
ENV APACHE_DOCUMENT_ROOT=/var/www/html/web

RUN apt-get update && apt-get install -y 
git 
unzip 
curl 
ca-certificates 
libpq-dev 
libpng-dev 
libjpeg-dev 
libfreetype6-dev 
libzip-dev 
libicu-dev 
libxml2-dev 
libonig-dev 
libwebp-dev 
postgresql-client 
&& docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp 
&& docker-php-ext-install 
pdo 
pdo_pgsql 
pgsql 
gd 
zip 
intl 
mbstring 
opcache 
bcmath 
soap 
exif 
&& a2enmod rewrite headers expires 
&& echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf 
&& a2enconf servername 
&& sed -ri 
-e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' 
/etc/apache2/sites-available/*.conf 
&& sed -ri 
-e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' 
/etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf 
&& rm -rf /var/lib/apt/lists/*

COPY php.ini /usr/local/etc/php/conf.d/opigno.ini

RUN curl -sS https://getcomposer.org/installer | php -- 
--install-dir=/usr/local/bin 
--filename=composer 
&& composer --version

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /var/www/html

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["apache2-foreground"]
