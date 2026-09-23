#!/bin/sh
# ---------------------------------------------------------------
# WordPress / php-fpm entrypoint.
# Waits for MariaDB, installs WordPress once, then hands the
# process over to php-fpm with `exec`.
# ---------------------------------------------------------------
set -e

# Credentials come from the Docker secrets mounted at /run/secrets.
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

cd /var/www/html

# ---- 1. Wait for MariaDB to accept connections -----------------
# This loop is BOUNDED (120 s maximum) and always terminates: it is
# a readiness check, not the "infinite loop" the subject forbids.
i=0
until mariadb -h "${WORDPRESS_DB_HOST}" \
              -u "${MYSQL_USER}" \
              -p"${MYSQL_PASSWORD}" \
              -e "SELECT 1;" > /dev/null 2>&1
do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
        echo "[wordpress] MariaDB unreachable after 60 attempts, aborting" >&2
        exit 1
    fi
    echo "[wordpress] waiting for MariaDB ($i/60)"
    sleep 2
done
echo "[wordpress] MariaDB is ready"

# ---- 2. Install WordPress on the first run only ----------------
if [ ! -f /var/www/html/wp-config.php ]; then

    echo "[wordpress] downloading the WordPress core"
    wp core download --allow-root --path=/var/www/html

    echo "[wordpress] writing wp-config.php"
    wp config create --allow-root --path=/var/www/html \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="${WORDPRESS_DB_HOST}" \
        --skip-check

    echo "[wordpress] installing the site"
    wp core install --allow-root --path=/var/www/html \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email

    echo "[wordpress] creating the second user '${WP_USER}'"
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" --allow-root \
        --path=/var/www/html \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}"

    echo "[wordpress] installation complete"
else
    echo "[wordpress] existing installation found, starting as is"
fi

chown -R nobody:nobody /var/www/html

# `exec` replaces this shell, so php-fpm becomes PID 1.
exec php-fpm -F
