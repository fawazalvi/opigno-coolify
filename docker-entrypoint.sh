#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/www/html/opigno-install.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

cd /var/www/html

log "Starting Opigno container..."
log "DB_HOST=${DB_HOST:-not_set}"
log "DB_PORT=${DB_PORT:-not_set}"
log "DB_NAME=${DB_NAME:-not_set}"
log "DB_USER=${DB_USER:-not_set}"
log "SITE_NAME=${SITE_NAME:-not_set}"
log "OPIGNO_VERSION=${OPIGNO_VERSION:-3.2.7}"

export COMPOSER_MEMORY_LIMIT=-1
export COMPOSER_PROCESS_TIMEOUT=0

mkdir -p /var/www/html

if [ ! -f /var/www/html/web/sites/default/default.settings.php ]; then
  log "Drupal/Opigno code is missing or incomplete."
  log "Cleaning existing partial code from /var/www/html..."

  find /var/www/html -mindepth 1 \
    ! -path "/var/www/html/private" \
    ! -path "/var/www/html/private/*" \
    ! -path "/var/www/html/web/sites/default/files" \
    ! -path "/var/www/html/web/sites/default/files/*" \
    -exec rm -rf {} + 2>/dev/null || true

  rm -rf /tmp/opigno

  log "Composer version:"
  composer --version 2>&1 | tee -a "$LOG_FILE"

  log "Applying Composer global configuration..."

  composer config --global audit.block-insecure false || true
  composer config --global allow-plugins.composer/installers true || true
  composer config --global allow-plugins.drupal/core-composer-scaffold true || true
  composer config --global allow-plugins.cweagans/composer-patches true || true
  composer config --global allow-plugins.wikimedia/composer-merge-plugin true || true
  composer config --global allow-plugins.mglaman/composer-drupal-lenient true || true

  log "Downloading Opigno project from Packagist without installing dependencies..."

  composer create-project opigno/opigno-composer:"${OPIGNO_VERSION:-3.2.7}" /tmp/opigno \
    --stability stable \
    --no-install \
    --no-interaction \
    --no-audit \
    -vvv 2>&1 | tee -a "$LOG_FILE"

  log "Configuring Drupal package repository inside Opigno project..."

  cd /tmp/opigno

  composer config repositories.drupal composer https://packages.drupal.org/8 || true
  composer config audit.block-insecure false || true
  composer config allow-plugins.composer/installers true || true
  composer config allow-plugins.drupal/core-composer-scaffold true || true
  composer config allow-plugins.cweagans/composer-patches true || true
  composer config allow-plugins.wikimedia/composer-merge-plugin true || true
  composer config allow-plugins.mglaman/composer-drupal-lenient true || true

  log "Installing Opigno/Drupal dependencies..."

  composer install \
    --no-interaction \
    --no-audit \
    -vvv 2>&1 | tee -a "$LOG_FILE"

  log "Installing or confirming Drush..."

  composer require drush/drush:^12 \
    --with-all-dependencies \
    --no-interaction \
    --no-audit \
    -vvv 2>&1 | tee -a "$LOG_FILE"

  log "Copying Opigno code into /var/www/html..."

  cp -a /tmp/opigno/. /var/www/html/
  rm -rf /tmp/opigno

  cd /var/www/html

  chown -R www-data:www-data /var/www/html

  log "Opigno code installation completed."
else
  log "Drupal/Opigno code exists. Skipping Composer create-project."
fi

cd /var/www/html

if [ ! -f web/sites/default/default.settings.php ]; then
  log "ERROR: default.settings.php still not found after Composer install."
  log "Directory listing:"
  find /var/www/html -maxdepth 5 -type d | sort | tee -a "$LOG_FILE"
  exit 1
fi

mkdir -p web/sites/default/files private
chown -R www-data:www-data web/sites/default/files private
chmod -R 775 web/sites/default/files private

if [ ! -f web/sites/default/settings.php ]; then
  log "Creating settings.php..."
  cp web/sites/default/default.settings.php web/sites/default/settings.php
  chown www-data:www-data web/sites/default/settings.php
  chmod 664 web/sites/default/settings.php
fi

log "Checking PostgreSQL connection..."

until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"; do
  log "Waiting for PostgreSQL..."
  sleep 5
done

log "PostgreSQL is accepting connections."

if [ ! -f web/sites/default/files/.opigno_installed ]; then
  log "Installing Opigno LMS site into database..."

  vendor/bin/drush site:install opigno_lms \
    --db-url="pgsql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}" \
    --account-name="${ADMIN_USER}" \
    --account-pass="${ADMIN_PASS}" \
    --account-mail="${ADMIN_EMAIL}" \
    --site-mail="${ADMIN_EMAIL}" \
    --site-name="${SITE_NAME}" \
    -y -vvv 2>&1 | tee -a "$LOG_FILE"

  log "Drush site install completed."

  touch web/sites/default/files/.opigno_installed

  log "Clearing Drupal cache..."
  vendor/bin/drush cr -vvv 2>&1 | tee -a "$LOG_FILE"

  chown -R www-data:www-data /var/www/html
  chmod -R 775 web/sites/default/files private

  log "Opigno LMS installation completed successfully."
else
  log "Opigno database already installed. Skipping site install."
fi

log "Starting Apache..."

exec "$@"
