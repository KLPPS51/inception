# Penultimate stable Alpine, pinned explicitly. The `latest` tag is
# forbidden by the subject. Check https://alpinelinux.org/releases/
# before the defense and update this line in all three Dockerfiles
# if the penultimate stable release has moved.
FROM alpine:3.23

# Passed by docker-compose.yml from DOMAIN_NAME in srcs/.env, and used
# only as the certificate's common name. It is not a credential.
ARG DOMAIN_NAME=localhost

RUN apk update && apk add --no-cache nginx openssl

# Self-signed certificate, generated at build time. The subject allows
# a certificate that is not signed by a recognised authority.
RUN mkdir -p /etc/nginx/ssl /var/www/html /run/nginx \
    && openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out    /etc/nginx/ssl/inception.crt \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=${DOMAIN_NAME}"

COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

# nginx runs in the foreground and is therefore PID 1: it receives the
# SIGTERM sent by `docker stop` directly. No daemon, no background job,
# no infinite loop.
CMD ["nginx", "-g", "daemon off;"]
