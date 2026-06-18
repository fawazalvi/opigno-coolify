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
  composer config --global allow-plugins.drupal/core-project-message true || true
  composer config --global allow-plugins.cweagans/composer-patches true || true
  composer config --global allow-plugins.wikimedia/composer-merge-plugin true || true
  composer config --global allow-plugins.mglaman/composer-drupal-lenient true || true

  log "Downloading Opigno project from Packagist without installing dependencies..."

  composer create-project opigno/opigno-composer:"${OPIGNO_VERSION:-3.2.7}" /tmp/opigno \
    --stability stable \
    --no-install \
    --no-interaction \
    --no-security-blocking \
    -vvv 2>&1 | tee -a "$LOG_FILE"

  cd /tmp/opigno

  log "Configuring Drupal package repository inside Opigno project..."

  composer config repositories.drupal composer https://packages.drupal.org/8 || true

  # Opigno requires alpha and dev/master dependencies.
  composer config minimum-stability dev || true
  composer config prefer-stable true || true

  composer config audit.block-insecure false || true
  composer config allow-plugins.composer/installers true || true
  composer config allow-plugins.drupal/core-composer-scaffold true || true
  composer config allow-plugins.drupal/core-project-message true || true
  composer config allow-plugins.cweagans/composer-patches true || true
  composer config allow-plugins.wikimedia/composer-merge-plugin true || true
  composer config allow-plugins.mglaman/composer-drupal-lenient true || true

  log "Patching composer.json to force Drupal 10 and allow Opigno dependencies..."

  php -r '
  $file = "composer.json";
  $json = json_decode(file_get_contents($file), true);

  if (!isset($json["require"])) {
    $json["require"] = [];
  }

  // Pin Drupal 10 recommended packages.
  $json["require"]["drupal/core-recommended"] = "^10.0";
  $json["require"]["drupal/core-composer-scaffold"] = "^10.0";
  $json["require"]["drupal/core-project-message"] = "^10.0";

  // Opigno 3.2.7 is Drupal 10 based.
  $json["require"]["opigno/opigno_lms"] = "~3.2.0";

  // Opigno required contrib/dev dependencies.
  $json["require"]["drupal/calendar"] = "^1.0@alpha";
  $json["require"]["drupal/color"] = "^1.0";
  $json["require"]["furf/jquery-ui-touch-punch"] = "dev-master";

  // H5P PHP libraries required by Drupal h5p module.
  $json["require"]["h5p/h5p-core"] = "^1.26";
  $json["require"]["h5p/h5p-editor"] = "^1.25";

  // These modules exist in Drupal core / create conflict as contrib packages.
  if (!isset($json["replace"])) {
    $json["replace"] = [];
  }

  $json["replace"]["drupal/forum"] = "*";
  $json["replace"]["drupal/history"] = "*";

  // Ensure H5P libraries are not accidentally marked as replaced.
  unset($json["replace"]["h5p/h5p-core"]);
  unset($json["replace"]["h5p/h5p-editor"]);

  // Opigno 3.2.7 has alpha and dev/master dependencies.
  $json["minimum-stability"] = "dev";
  $json["prefer-stable"] = true;

  file_put_contents(
    $file,
    json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL
  );
  '

  log "Current composer.json relevant entries:"
  php -r '
  $json = json_decode(file_get_contents("composer.json"), true);

  echo "minimum-stability: " . ($json["minimum-stability"] ?? "not set") . PHP_EOL;
  echo "prefer-stable: " . (($json["prefer-stable"] ?? false) ? "true" : "false") . PHP_EOL;

  echo "require:\n";
  foreach ($json["require"] as $k => $v) {
    if (
      str_contains($k, "drupal/") ||
      str_contains($k, "opigno/") ||
      str_contains($k, "furf/") ||
      str_contains($k, "h5p/")
    ) {
      echo "  $k: $v\n";
    }
  }

  echo "replace:\n";
  foreach (($json["replace"] ?? []) as $k => $v) {
    if (str_contains($k, "drupal/") || str_contains($k, "h5p/")) {
      echo "  $k: $v\n";
    }
  }
  ' 2>&1 | tee -a "$LOG_FILE"

  log "Resolving and installing Opigno/Drupal dependencies..."

  composer update \
    --with-all-dependencies \
    --no-interaction \
    --no-security-blocking \
    -vvv 2>&1 | tee -a "$LOG_FILE"

  log "Regenerating optimized Composer autoload files..."

  composer dump-autoload -o 2>&1 | tee -a "$LOG_FILE"

  log "Verifying H5PFrameworkInterface availability..."

  php -r '
  require "vendor/autoload.php";
  if (interface_exists("H5PFrameworkInterface")) {
    echo "H5PFrameworkInterface loaded successfully.\n";
    exit(0);
  }
  echo "ERROR: H5PFrameworkInterface still not available.\n";
  exit(1);
  ' 2>&1 | tee -a "$LOG_FILE"

  log "Checking Drush availability..."

  if [ ! -x /tmp/opigno/vendor/bin/drush ]; then
    log "Drush not found. Installing Drush..."

    composer require drush/drush:^12 \
      --with-all-dependencies \
      --no-interaction \
      --no-security-blocking \
      -vvv 2>&1 | tee -a "$LOG_FILE"

    composer dump-autoload -o 2>&1 | tee -a "$LOG_FILE"
  else
    log "Drush already available."
  fi

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

log "Preparing Drupal writable directories..."

mkdir -p web/sites/default/files
mkdir -p web/sites/default/files/media-icons
mkdir -p web/sites/default/files/media-icons/generic
mkdir -p web/sites/default/files/php
mkdir -p web/sites/default/files/css
mkdir -p web/sites/default/files/js
mkdir -p private

chown -R www-data:www-data web/sites/default/files private
chmod -R 777 web/sites/default/files private

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

  ENC_DB_USER="$(php -r 'echo rawurlencode(getenv("DB_USER"));')"
  ENC_DB_PASS="$(php -r 'echo rawurlencode(getenv("DB_PASS"));')"

  vendor/bin/drush site:install opigno_lms \
    --db-url="pgsql://${ENC_DB_USER}:${ENC_DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}" \
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
