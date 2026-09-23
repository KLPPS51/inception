#!/bin/sh
# ---------------------------------------------------------------
# MariaDB entrypoint.
# Initialises the data directory on the very first start, then
# hands the process over to the daemon with `exec`.
# ---------------------------------------------------------------
set -e

# Credentials are read from the Docker secrets mounted read-only
# at /run/secrets. They never appear in the image or in `docker inspect`.
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
MYSQL_PASSWORD=$(cat /run/secrets/db_password)

mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# The named volume is empty only on the very first run.
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "[mariadb] first start: creating the data directory"
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db > /dev/null

    INIT_SQL=$(mktemp)
    cat > "$INIT_SQL" <<SQL
USE mysql;
FLUSH PRIVILEGES;

ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

DROP DATABASE IF EXISTS test;
DELETE FROM mysql.user WHERE User='';

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`
    CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

FLUSH PRIVILEGES;
SQL

    mariadbd --user=mysql --bootstrap < "$INIT_SQL"
    rm -f "$INIT_SQL"
    echo "[mariadb] database '${MYSQL_DATABASE}' and user '${MYSQL_USER}' created"
else
    echo "[mariadb] existing data directory found, starting as is"
fi

# `exec` replaces this shell, so mariadbd becomes PID 1 and receives
# SIGTERM from `docker stop` directly. No background job, no loop.
exec mariadbd --user=mysql --console
