#!/usr/bin/env bash
set -e

cd /var/www/html

mkdir -p web/sites/default/files private
chown -R www-data:www-data web/sites/default/files private
chmod -R 775 web/sites/default/files private

if [ ! -f web/sites/default/settings.php ]; then
  echo "Preparing Drupal settings.php..."
  cp web/sites/default/default.settings.php web/sites/default/settings.php
  chown www-data:www-data web/sites/default/settings.php
  chmod 664 web/sites/default/settings.php
fi

if [ ! -f web/sites/default/files/.opigno_installed ]; then
  echo "Checking PostgreSQL connection..."

  until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"; do
    echo "Waiting for PostgreSQL..."
    sleep 5
  done

  echo "Installing Opigno LMS..."

  vendor/bin/drush site:install opigno_lms \
    --db-url="pgsql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}" \
    --account-name="${ADMIN_USER}" \
    --account-pass="${ADMIN_PASS}" \
    --account-mail="${ADMIN_EMAIL}" \
    --site-mail="${ADMIN_EMAIL}" \
    --site-name="${SITE_NAME}" \
    -y

  touch web/sites/default/files/.opigno_installed

  chown -R www-data:www-data web/sites/default/files private
  vendor/bin/drush cr
else
  echo "Opigno already installed. Skipping installation."
fi

exec "$@"
