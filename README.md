*This project has been created as part of the 42 curriculum by mobullad*

# Inception

## Description

Inception is a system administration project. Its goal is to build a small
web infrastructure from scratch, inside a virtual machine, using Docker and
Docker Compose.

The infrastructure is made of three services, each one running in its own
container, each one built from a Dockerfile written for this project:

| Service     | Role                                                        |
| ----------- | ----------------------------------------------------------- |
| `nginx`     | The single entry point. Terminates TLS on port 443 and forwards PHP requests over FastCGI. |
| `wordpress` | WordPress served by php-fpm. No web server inside.          |
| `mariadb`   | The database backing WordPress. No web server inside.       |

The three containers are attached to a user-defined bridge network named
`inception`, and two Docker named volumes persist the database and the
WordPress files on the host, under `/home/mobullad/data`.

Requests flow like this:

```
                         host
                           |
                     443/tcp (TLS)
                           |
   +-----------------------v-----------------------+
   |                  nginx container              |
   |   terminates TLSv1.2 / TLSv1.3                |
   |   serves static files, forwards *.php         |
   +-----------------------+-----------------------+
                           | FastCGI, port 9000
   +-----------------------v-----------------------+
   |               wordpress container             |
   |   php-fpm executes the PHP code               |
   +-----------------------+-----------------------+
                           | MySQL protocol, port 3306
   +-----------------------v-----------------------+
   |                mariadb container              |
   +-----------------------------------------------+

            all three on the `inception` bridge network
```

Nothing but port 443 is published to the host. Ports 9000 and 3306 are
reachable only from inside the Docker network.

## Project description

### Docker and the sources used in this project

Docker is used here in the way the subject requires: no ready-made image is
pulled from Docker Hub. The only images fetched from outside are the Alpine
base images, which the subject explicitly allows. Everything on top of them
is described by the three Dockerfiles in `srcs/requirements/`.

The sources included in the repository are:

- `Makefile` — the single entry point for building and running the project.
- `srcs/docker-compose.yml` — the declaration of the three services, the
  network, the two named volumes and the four secrets.
- `srcs/.env.example` — the template for the non-sensitive configuration.
- `srcs/requirements/<service>/Dockerfile` — one image recipe per service.
- `srcs/requirements/<service>/conf/` — the configuration files copied into
  the images (`nginx.conf`, `www.conf`, `50-server.cnf`).
- `srcs/requirements/<service>/tools/init.sh` — the entrypoint scripts for
  MariaDB and WordPress, which perform the one-time initialisation.
- `tools/gen_secrets.sh` — generates the local password files.

### Main design choices

**One process per container, started in the foreground.** Each container
runs its daemon in the foreground so that the daemon is PID 1:
`nginx -g "daemon off;"`, `mariadbd --console`, `php-fpm -F`. PID 1 is the
process that receives the signals sent by `docker stop`, so this is what
makes the containers shut down cleanly. No `tail -f`, no `sleep infinity`,
no background job.

**Entrypoint scripts that end with `exec`.** MariaDB and WordPress need a
one-time setup before their daemon can start, so their entrypoint is a
script. Each script finishes with `exec <daemon>`, which *replaces* the
shell process instead of forking a child. The daemon therefore inherits
PID 1 and the shell disappears.

**Initialisation guarded by a test on the volume.** Both scripts check
whether the work has already been done (`/var/lib/mysql/mysql` for MariaDB,
`wp-config.php` for WordPress). On the first start they initialise; on every
later start they go straight to the daemon. This is what makes the stack
survive a reboot without reinstalling anything.

**A bounded wait instead of a fixed sleep.** `depends_on` only guarantees
that MariaDB was *started*, not that it accepts connections. The WordPress
entrypoint therefore polls the database, but with a hard limit of 60
attempts: it is a readiness check that always terminates, not an infinite
loop.

**Configuration through the environment, credentials through secrets.**
`srcs/.env` carries names, hosts and the domain. Every password is a file
under `secrets/`, mounted read-only into the containers. See the comparison
below.

**Alpine as the base image.** Alpine produces much smaller images than
Debian and its package manager is straightforward. The subject requires the
penultimate stable version; the three Dockerfiles pin it explicitly rather
than using `latest`, which is forbidden.

### Virtual Machines vs Docker

A virtual machine emulates a whole machine: the hypervisor provides virtual
hardware, and a complete guest operating system boots on top of it, with its
own kernel. A container does not do that. It is a normal process on the host,
isolated by two Linux kernel features: namespaces, which give it its own view
of the filesystem, the network and the process tree, and cgroups, which limit
the resources it can consume. A container shares the host kernel.

The practical consequences are: a container starts in milliseconds where a VM
boots in tens of seconds; a container image is measured in megabytes where a
VM disk image is measured in gigabytes; and a host can run hundreds of
containers where it would run a handful of VMs.

The trade-off is the isolation boundary. A VM is isolated at the hardware
level and can run a different kernel, so it can run Windows on a Linux host
and it contains a kernel-level compromise. A container shares the kernel, so
it can only run Linux on Linux and a kernel vulnerability is a vulnerability
for every container on the host.

This project uses both, and that is deliberate: Docker runs inside a virtual
machine, so the VM provides the strong boundary with the school workstation
while Docker provides the cheap, reproducible boundary between the three
services.

### Secrets vs Environment Variables

An environment variable is readable by anyone who can inspect the container.
`docker inspect`, `docker compose config` and `/proc/<pid>/environ` all
expose it, it is inherited by every child process, and it frequently ends up
in logs and crash reports. Worse, a variable defined in a Dockerfile with
`ENV` is baked into an image layer and travels with the image forever.

A Docker secret is a file. Compose mounts it read-only at
`/run/secrets/<name>` inside the container, it is never part of any image
layer, and it does not appear in the container's environment. The process
reads it when it needs it.

This project uses both, according to sensitivity:

- `srcs/.env` holds what is not secret: the domain name, the database name,
  the user names, the host names. This mirrors the example given in the
  subject.
- `secrets/` holds the four passwords: the MariaDB root password, the
  MariaDB user password, and the two WordPress passwords.

Neither file is committed. `srcs/.env` is generated from
`srcs/.env.example` by the Makefile, and `secrets/` is emptied by its own
`.gitignore`, so the repository contains no credential of any kind.

### Docker Network vs Host Network

With `network_mode: host`, a container skips network namespace isolation
entirely and uses the host's network stack directly. Its services bind
directly to the host's interfaces. There is no port mapping because there is
nothing to map, and there is no isolation either: every port opened by every
container is opened on the host, and two containers cannot both listen on
port 3306.

A user-defined bridge network, which is what this project uses, gives the
containers a private network of their own. Three things follow.

First, Docker runs an embedded DNS server on that network, so containers
resolve each other *by service name*. This is why `nginx.conf` can say
`fastcgi_pass wordpress:9000` and the WordPress entrypoint can connect to
`mariadb`, with no IP address written anywhere and no `links:` directive.

Second, only what is explicitly published with `ports:` is reachable from
the host. The project publishes `443:443` and nothing else, which is exactly
the subject's requirement that NGINX be the only entry point. MariaDB and
php-fpm use `expose:`, which documents the port on the internal network
without opening it on the host.

Third, the network is a security boundary. The database is simply not
reachable from outside the Docker network.

`network_mode: host` and `links:` are both forbidden by the subject, and the
reasons above are why.

### Docker Volumes vs Bind Mounts

A bind mount attaches an existing host path into a container:
`-v /home/user/stuff:/var/www`. The container sees whatever is at that path.
It depends on the host's directory layout, Docker does not manage it, and it
is not visible to `docker volume ls`.

A named volume is a storage object managed by Docker. It is created,
listed, inspected and removed through the Docker API, it has a lifecycle
independent of any container, and several containers can mount it at once.
That last point matters here: `wordpress_data` is mounted by *both* the
WordPress container and the NGINX container. php-fpm receives a file path
over FastCGI, not the file itself, so both containers must see the same
files at the same path.

The subject requires named volumes, forbids bind mounts, and at the same
time requires the data to end up under `/home/mobullad/data`. These are
reconciled with the `local` driver's options:

```yaml
volumes:
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_PATH}/wordpress
```

This is a named volume: it is declared in the top-level `volumes:` section,
the services reference it by name, and `docker volume ls` lists it. The
`driver_opts` only tell the local driver where to store its contents.
`docker volume inspect wordpress_data` shows both facts at once.

## Instructions

### Prerequisites

- A virtual machine running Debian or Ubuntu.
- Docker Engine and the Docker Compose plugin. If they are not installed,
  `sh tools/install_docker_debian.sh` installs them, after which you must log
  out and back in so that your user picks up the `docker` group.
- `make` and `sudo`.

### Installation and execution

```sh
git clone <repository-url> inception
cd inception
make hosts     # adds "127.0.0.1 mobullad.42.fr" to /etc/hosts, asks for sudo
make           # generates .env and the secrets, then builds and starts
```

`make` performs, in order: it copies `srcs/.env.example` to `srcs/.env`, it
generates the four password files in `secrets/` if they do not exist yet, it
creates `/home/mobullad/data/{mariadb,wordpress}`, and it runs
`docker compose up -d --build`.

The first build downloads the Alpine packages and the WordPress core, so it
takes a few minutes. Follow it with `make logs`.

Then open **https://mobullad.42.fr**. The certificate is self-signed, so the
browser shows a warning; accept it. `http://mobullad.42.fr` is expected to
fail: port 80 is not published.

### Everyday commands

| Command            | Effect                                              |
| ------------------ | --------------------------------------------------- |
| `make`             | Build the images and start the stack                |
| `make down`        | Stop and remove the containers, keep the volumes    |
| `make re`          | Full rebuild from scratch                           |
| `make logs`        | Follow the logs of the three containers             |
| `make ps`          | Show the state of the containers                    |
| `make credentials` | Print the generated passwords                       |
| `make clean`       | Remove the containers and the named volumes         |
| `make fclean`      | `clean`, plus the images and the persisted data     |

Log in to the administration panel at
`https://mobullad.42.fr/wp-admin`. `make credentials` prints the user names
and passwords.

Further detail is in `USER_DOC.md` for day-to-day operation and in
`DEV_DOC.md` for development and maintenance.

## Resources

### Documentation

- Docker, *Dockerfile reference* — https://docs.docker.com/reference/dockerfile/
- Docker, *Compose file reference* — https://docs.docker.com/reference/compose-file/
- Docker, *Use secrets in Compose* — https://docs.docker.com/compose/how-tos/use-secrets/
- Docker, *Networking overview* — https://docs.docker.com/engine/network/
- Docker, *Volumes* — https://docs.docker.com/engine/storage/volumes/
- Docker, *Best practices for writing Dockerfiles* — https://docs.docker.com/build/building/best-practices/
- NGINX, *Configuring HTTPS servers* — https://nginx.org/en/docs/http/configuring_https_servers.html
- NGINX, *ngx_http_fastcgi_module* — https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- PHP, *FPM configuration* — https://www.php.net/manual/en/install.fpm.configuration.php
- MariaDB, *mariadb-install-db* — https://mariadb.com/kb/en/mariadb-install-db/
- WP-CLI, *Command reference* — https://developer.wordpress.org/cli/commands/
- Alpine Linux, *Releases* — https://alpinelinux.org/releases/
- Eric Ross, *What is PID 1 and why does it matter in containers* —
  https://cloud.google.com/architecture/best-practices-for-building-containers

### How AI was used

An AI assistant (Claude) was used on this project for the following tasks,
and only for those:

- **Generating the initial file structure.** The work was done on a virtual
  machine without a graphical interface and without a clipboard, so every
  file would otherwise have been typed by hand. The assistant produced the
  first version of the Dockerfiles, `docker-compose.yml`, the configuration
  files, the entrypoint scripts and the Makefile, which were then delivered
  through Git rather than retyped.
- **Writing the documentation.** The first draft of this README, of
  `USER_DOC.md` and of `DEV_DOC.md` was generated, then reviewed and
  corrected.
- **Cross-checking against the subject.** The assistant was given the
  subject and the evaluation sheet and asked to list the requirements the
  first version did not meet. This is how the credentials were moved out of
  `.env` and into Docker secrets.

AI was **not** used to decide the architecture without understanding it.
Every generated file was read, tested and, where necessary, corrected. The
sections above on PID 1, on named volumes and on the bridge network describe
choices I can justify and reproduce.

> Adapt this section so that it matches exactly what you did. An honest and
> specific account is worth more than a vague one, and you will be asked
> about it during the defense.
