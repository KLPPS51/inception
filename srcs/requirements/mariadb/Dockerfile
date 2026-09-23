# Penultimate stable Alpine, pinned explicitly. The `latest` tag is
# forbidden by the subject. Check https://alpinelinux.org/releases/
# before the defense and update this line in all three Dockerfiles
# if the penultimate stable release has moved.
FROM alpine:3.20

RUN apk update && apk add --no-cache mariadb mariadb-client

COPY conf/50-server.cnf /etc/my.cnf.d/50-server.cnf
COPY tools/init.sh      /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

EXPOSE 3306

# The entrypoint is a script because the data directory has to be created
# on the first start. It ends with `exec mariadbd`, so the daemon replaces
# the shell and becomes PID 1. Nothing runs in the background.
ENTRYPOINT ["/usr/local/bin/init.sh"]
