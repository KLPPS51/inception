# Penultimate stable Alpine, pinned explicitly. The `latest` tag is
# forbidden by the subject. Check https://alpinelinux.org/releases/
# before the defense and update this line in all three Dockerfiles
# if the penultimate stable release has moved.
FROM alpine:3.20

# On Alpine the PHP packages carry their version in their name, and each
# Alpine release ships one PHP version: 3.19 -> 82, 3.20 -> 83, 3.21 -> 84.
# Keep this in step with the FROM line above.
ARG PHP_VER=83

RUN apk update && apk add --no-cache \
        php${PHP_VER} \
        php${PHP_VER}-fpm \
        php${PHP_VER}-mysqli \
        php${PHP_VER}-json \
        php${PHP_VER}-curl \
        php${PHP_VER}-dom \
        php${PHP_VER}-exif \
        php${PHP_VER}-fileinfo \
        php${PHP_VER}-mbstring \
        php${PHP_VER}-openssl \
        php${PHP_VER}-xml \
        php${PHP_VER}-zip \
        php${PHP_VER}-session \
        php${PHP_VER}-phar \
        php${PHP_VER}-iconv \
        php${PHP_VER}-tokenizer \
        php${PHP_VER}-simplexml \
        php${PHP_VER}-xmlreader \
        php${PHP_VER}-xmlwriter \
        php${PHP_VER}-ctype \
        php${PHP_VER}-gd \
        php${PHP_VER}-opcache \
        curl mariadb-client \
    && ln -sf /usr/bin/php${PHP_VER}      /usr/bin/php \
    && ln -sf /usr/sbin/php-fpm${PHP_VER} /usr/sbin/php-fpm

# The destination path depends on PHP_VER, so copy to a fixed location
# first and move it afterwards.
COPY conf/www.conf /tmp/www.conf
RUN mv /tmp/www.conf /etc/php${PHP_VER}/php-fpm.d/www.conf

# WP-CLI drives the installation from the entrypoint script, so the site
# is ready without ever going through the web installer.
RUN curl -fsSL -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh \
    && mkdir -p /var/www/html /run/php

WORKDIR /var/www/html

EXPOSE 9000

# The entrypoint is a script because WordPress has to be installed on the
# first start. It ends with `exec php-fpm -F`, so php-fpm replaces the
# shell and becomes PID 1. Nothing runs in the background.
ENTRYPOINT ["/usr/local/bin/init.sh"]
