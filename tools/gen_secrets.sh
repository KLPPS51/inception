#!/bin/sh
# ---------------------------------------------------------------
# Generates the secret files expected by docker-compose.yml.
#
# Each file holds one password and nothing else. The directory is
# listed in .gitignore, so no credential is ever committed.
# Existing files are never overwritten: run this as many times as
# you like, it is idempotent.
# ---------------------------------------------------------------
set -e

SECRETS_DIR="$(dirname "$0")/../secrets"
mkdir -p "$SECRETS_DIR"

# 24 random alphanumeric characters, no trailing newline.
random_password()
{
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24
}

for name in db_root_password db_password wp_admin_password wp_user_password
do
    file="$SECRETS_DIR/$name.txt"
    if [ -f "$file" ]; then
        echo "[secrets] $name.txt already exists, left untouched"
    else
        random_password > "$file"
        chmod 600 "$file"
        echo "[secrets] $name.txt generated"
    fi
done
