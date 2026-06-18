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
log "TRUSTED_HOST=${TRUSTED_HOST:-lms.global-hrm.net}"

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

  composer config minimum-stability dev || true
  composer config prefer-stable true || true

  composer config audit.block-insecure false || true
  composer config allow-plugins.composer/installers true || true
  composer config allow-plugins.drupal/core-composer-scaffold true || true
  composer config allow-plugins.drupal/core-project-message true || true
  composer config allow-plugins.cweagans/composer-patches true || true
  composer config allow-plugins.wikimedia/composer-merge-plugin true || true
  composer config allow-plugins.mglaman/composer-drupal-lenient true || true

  log "Patching composer.json to force Drupal 10.2 and resolve Opigno dependencies..."

  php -r '
  $file = "composer.json";
  $json = json_decode(file_get_contents($file), true);

  if (!isset($json["require"])) {
    $json["require"] = [];
  }

  $json["require"]["drupal/core-recommended"] = "10.2.*";
  $json["require"]["drupal/core-composer-scaffold"] = "10.2.*";
  $json["require"]["drupal/core-project-message"] = "10.2.*";

  $json["require"]["opigno/opigno_lms"] = "~3.2.0";

  $json["require"]["drupal/calendar"] = "^1.0@alpha";
  $json["require"]["drupal/color"] = "^1.0";
  $json["require"]["drupal/private_message"] = "^3.0";
  $json["require"]["furf/jquery-ui-touch-punch"] = "dev-master";

  $json["require"]["drupal/h5p"] = "2.0.0-alpha5";
  $json["require"]["h5p/h5p-core"] = ">=1.26 <1.28";
  $json["require"]["h5p/h5p-editor"] = "^1.25";

  if (!isset($json["replace"])) {
    $json["replace"] = [];
  }

  $json["replace"]["drupal/forum"] = "*";
  $json["replace"]["drupal/history"] = "*";

  unset($json["replace"]["h5p/h5p-core"]);
  unset($json["replace"]["h5p/h5p-editor"]);

  if (isset($json["extra"]["patches"]["drupal/calendar"])) {
    unset($json["extra"]["patches"]["drupal/calendar"]);
  }

  if (isset($json["extra"]["patches"]) && empty($json["extra"]["patches"])) {
    unset($json["extra"]["patches"]);
  }

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

  echo "patches:\n";
  foreach (($json["extra"]["patches"] ?? []) as $package => $patches) {
    echo "  $package\n";
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

  log "Patching private_message config to use Drupal core autocomplete widget..."

  if [ -d /tmp/opigno/web/modules/contrib/private_message ]; then
    find /tmp/opigno/web/modules/contrib/private_message \
      \( -path "*/config/install/*.yml" -o -path "*/config/optional/*.yml" \) \
      -type f \
      -exec grep -l "private_message_thread_member_widget" {} \; \
      | while read -r config_file; do
          log "Patching ${config_file}"
          sed -i 's/private_message_thread_member_widget/entity_reference_autocomplete/g' "$config_file"
        done

    log "Checking private_message config YAML references after patch..."

    if find /tmp/opigno/web/modules/contrib/private_message \
      \( -path "*/config/install/*.yml" -o -path "*/config/optional/*.yml" \) \
      -type f \
      -exec grep -l "private_message_thread_member_widget" {} \; \
      | grep -q .; then
      log "ERROR: private_message_thread_member_widget still found in install/optional config YAML."
      exit 1
    else
      log "private_message config YAML patch completed."
    fi
  else
    log "WARNING: private_message module directory not found. Skipping private_message config patch."
  fi

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

log "Ensuring Drupal database settings are present in settings.php..."

TRUSTED_HOST_VALUE="${TRUSTED_HOST:-lms.global-hrm.net}"
TRUSTED_HOST_REGEX="$(php -r 'echo "^" . str_replace("\\.", "\\\\.", preg_quote(getenv("TRUSTED_HOST") ?: "lms.global-hrm.net", "/")) . "$";')"

if ! grep -q "opigno_lms_env_database_settings" web/sites/default/settings.php; then
  cat >> web/sites/default/settings.php <<PHPSETTINGS

/**
 * opigno_lms_env_database_settings
 * Database settings injected by Docker entrypoint.
 */
\$databases['default']['default'] = [
  'database' => getenv('DB_NAME'),
  'username' => getenv('DB_USER'),
  'password' => getenv('DB_PASS'),
  'prefix' => '',
  'host' => getenv('DB_HOST'),
  'port' => getenv('DB_PORT') ?: '5432',
  'namespace' => 'Drupal\\\\pgsql\\\\Driver\\\\Database\\\\pgsql',
  'driver' => 'pgsql',
];

\$settings['hash_salt'] = 'opigno_lms_global_hrm_docker_hash_salt_2026';

\$settings['trusted_host_patterns'] = [
  '${TRUSTED_HOST_REGEX}',
  '^localhost$',
];

PHPSETTINGS

  chown www-data:www-data web/sites/default/settings.php
  chmod 664 web/sites/default/settings.php
else
  log "Drupal database settings already present in settings.php."
fi

log "Checking PostgreSQL connection..."

until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"; do
  log "Waiting for PostgreSQL..."
  sleep 5
done

log "PostgreSQL is accepting connections."

log "Installing PostgreSQL compatibility functions for Opigno/MySQL-style queries..."

export PGPASSWORD="$DB_PASS"

psql \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -v ON_ERROR_STOP=1 <<'SQLFUNCTIONS' 2>&1 | tee -a "$LOG_FILE"

CREATE OR REPLACE FUNCTION public.unix_timestamp(timestamp without time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(EPOCH FROM $1)::integer;
$$;

CREATE OR REPLACE FUNCTION public.unix_timestamp(timestamp with time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(EPOCH FROM $1)::integer;
$$;

CREATE OR REPLACE FUNCTION public.unix_timestamp(character varying)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(EPOCH FROM NULLIF($1, '')::timestamp)::integer;
$$;

CREATE OR REPLACE FUNCTION public.unix_timestamp(text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(EPOCH FROM NULLIF($1, '')::timestamp)::integer;
$$;

CREATE OR REPLACE FUNCTION public.week(timestamp without time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(WEEK FROM $1)::integer;
$$;

CREATE OR REPLACE FUNCTION public.week(timestamp with time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(WEEK FROM $1)::integer;
$$;

CREATE OR REPLACE FUNCTION public.week(character varying)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(WEEK FROM NULLIF($1, '')::timestamp)::integer;
$$;

CREATE OR REPLACE FUNCTION public.week(text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(WEEK FROM NULLIF($1, '')::timestamp)::integer;
$$;

CREATE OR REPLACE FUNCTION public.month(timestamp without time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(MONTH FROM $1)::integer;
$$;

CREATE OR REPLACE FUNCTION public.month(timestamp with time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(MONTH FROM $1)::integer;
$$;

CREATE OR REPLACE FUNCTION public.month(character varying)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(MONTH FROM NULLIF($1, '')::timestamp)::integer;
$$;

CREATE OR REPLACE FUNCTION public.month(text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(MONTH FROM NULLIF($1, '')::timestamp)::integer;
$$;

CREATE OR REPLACE FUNCTION public.year(timestamp without time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(YEAR FROM $1)::integer;
$$;

CREATE OR REPLACE FUNCTION public.year(timestamp with time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(YEAR FROM $1)::integer;
$$;

CREATE OR REPLACE FUNCTION public.year(character varying)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(YEAR FROM NULLIF($1, '')::timestamp)::integer;
$$;

CREATE OR REPLACE FUNCTION public.year(text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT EXTRACT(YEAR FROM NULLIF($1, '')::timestamp)::integer;
$$;

GRANT EXECUTE ON FUNCTION public.unix_timestamp(timestamp without time zone) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.unix_timestamp(timestamp with time zone) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.unix_timestamp(character varying) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.unix_timestamp(text) TO opigno_user;

GRANT EXECUTE ON FUNCTION public.week(timestamp without time zone) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.week(timestamp with time zone) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.week(character varying) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.week(text) TO opigno_user;

GRANT EXECUTE ON FUNCTION public.month(timestamp without time zone) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.month(timestamp with time zone) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.month(character varying) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.month(text) TO opigno_user;

GRANT EXECUTE ON FUNCTION public.year(timestamp without time zone) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.year(timestamp with time zone) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.year(character varying) TO opigno_user;
GRANT EXECUTE ON FUNCTION public.year(text) TO opigno_user;

SQLFUNCTIONS

unset PGPASSWORD

log "PostgreSQL compatibility functions installed."

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

  log "Clearing Drupal cache..."
  vendor/bin/drush cr -vvv 2>&1 | tee -a "$LOG_FILE" || true
fi

log "Starting Apache..."

exec "$@"
```
  
