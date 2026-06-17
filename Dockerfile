services:
  opigno:
    build:
      context: .
      dockerfile: Dockerfile

    restart: unless-stopped

    environment:
      DB_HOST: ${DB_HOST}
      DB_PORT: ${DB_PORT:-5432}
      DB_NAME: ${DB_NAME}
      DB_USER: ${DB_USER}
      DB_PASS: ${DB_PASS}

      ADMIN_USER: ${ADMIN_USER:-admin}
      ADMIN_PASS: ${ADMIN_PASS}
      ADMIN_EMAIL: ${ADMIN_EMAIL}
      SITE_NAME: ${SITE_NAME:-Opigno LMS}

      OPIGNO_VERSION: ${OPIGNO_VERSION:-3.2.7}

    volumes:
      - opigno_code:/var/www/html
      - opigno_files:/var/www/html/web/sites/default/files
      - opigno_private:/var/www/html/private

    expose:
      - "80"

volumes:
  opigno_code:
  opigno_files:
  opigno_private:
