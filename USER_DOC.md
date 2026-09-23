# User documentation

This document explains how to operate the Inception stack from day to day.
It assumes the project is already installed; see `README.md` for the
installation itself and `DEV_DOC.md` for development work.

## 1. What the stack provides

Starting the project brings up three containers.

| Container   | What it does                                                 | Reachable from      |
| ----------- | ------------------------------------------------------------ | ------------------- |
| `nginx`     | Receives every request on port 443, terminates TLS, serves static files and forwards PHP to `wordpress`. | The host, on port 443 only |
| `wordpress` | Runs the WordPress site through php-fpm.                     | The `inception` network only |
| `mariadb`   | Stores the WordPress database.                               | The `inception` network only |

From the outside, the whole stack looks like a single HTTPS website at
**https://mobullad.42.fr**.

## 2. Starting and stopping

All commands are run from the root of the repository.

| Action                                        | Command       |
| --------------------------------------------- | ------------- |
| Start the stack (builds the images if needed) | `make`        |
| Stop it, keeping the data                     | `make down`   |
| Start it again after `make down`              | `make`        |
| Restart from scratch, keeping the data        | `make down && make` |
| Rebuild everything, **deleting the data**     | `make re`     |

`make down` removes the containers but leaves the two named volumes intact,
so the site and the database are exactly as you left them when you start
again.

`make fclean` and `make re` delete the volumes and the contents of
`/home/mobullad/data`. The site is reinstalled from scratch on the next
start, and anything you published is lost.

### First start

The first `make` takes a few minutes: it builds three images, downloads the
WordPress core and installs the site. Watch it with `make logs` and wait for
these two lines:

```
wordpress  | [wordpress] installation complete
mariadb    | [mariadb] database 'wordpress' and user 'wpuser' created
```

### If the domain does not resolve

`mobullad.42.fr` must point at the loopback address. Run once:

```sh
make hosts
```

This appends `127.0.0.1 mobullad.42.fr` to `/etc/hosts` and asks for your
`sudo` password.

## 3. Accessing the site

| What                  | Address                              |
| --------------------- | ------------------------------------ |
| Public website        | `https://mobullad.42.fr`             |
| Administration panel  | `https://mobullad.42.fr/wp-admin`    |

Two things are expected and are not faults:

- **The browser warns about the certificate.** The certificate is
  self-signed, as the subject allows. Accept the warning and continue.
- **`http://mobullad.42.fr` does not work at all.** Port 80 is not
  published. HTTPS on port 443 is the only way in, by design.

## 4. Credentials

No password is stored in the repository. They are generated on your machine
the first time you run `make`, and they live in one file each under
`secrets/`:

```
secrets/db_root_password.txt     MariaDB root password
secrets/db_password.txt          MariaDB password for the WordPress user
secrets/wp_admin_password.txt    WordPress administrator password
secrets/wp_user_password.txt     WordPress author password
```

### Reading them

```sh
make credentials
```

This prints the user names, taken from `srcs/.env`, next to their passwords.
You can also read a single file directly:

```sh
cat secrets/wp_admin_password.txt
```

### The two WordPress accounts

| Account          | Name in `srcs/.env` | Role          | What it can do                    |
| ---------------- | ------------------- | ------------- | --------------------------------- |
| Administrator    | `WP_ADMIN_USER`     | Administrator | Everything, including the dashboard |
| Second user      | `WP_USER`           | Author        | Write and publish its own posts, comment |

The administrator's name must not contain `admin` or `administrator`; the
subject forbids it. The default is `bossman`.

### Changing a password

Passwords are read when a container starts, so changing one means restarting:

```sh
# 1. write the new password, with no trailing newline
printf 'my-new-password' > secrets/wp_admin_password.txt

# 2. restart
make down && make
```

For the two **WordPress** passwords this is not enough on an existing
installation: WordPress stored a hash of the password in the database when
the site was installed, and the entrypoint only creates the users once. To
change a WordPress password on a running site, use the dashboard, or:

```sh
docker exec -it wordpress wp user update bossman \
    --user_pass="my-new-password" --allow-root
```

Then write the same value into `secrets/wp_admin_password.txt` so that the
two stay in step.

Changing the **MariaDB** passwords on an existing installation has the same
caveat: they were applied when the data directory was created. Either change
them inside the database with `ALTER USER`, or run `make fclean` to start
over from an empty volume.

## 5. Checking that everything works

### Are the three containers up?

```sh
make ps
```

Each of `nginx`, `wordpress` and `mariadb` must show state `running`. A
container that keeps restarting is failing at startup: look at its logs.

```sh
make logs                  # all three, live
docker logs wordpress      # one of them, since the beginning
```

### Is HTTPS answering, and is HTTP really closed?

```sh
curl -kI https://mobullad.42.fr      # expected: HTTP/1.1 200 OK
curl -I  http://mobullad.42.fr       # expected: Connection refused
```

### Is TLS at the right version?

```sh
openssl s_client -connect mobullad.42.fr:443 -tls1_3 </dev/null
openssl s_client -connect mobullad.42.fr:443 -tls1_1 </dev/null
```

The first must succeed and report `Protocol: TLSv1.3`. The second must fail:
the subject only allows TLSv1.2 and TLSv1.3.

### Do the volumes point at the right place?

```sh
docker volume ls
docker volume inspect srcs_wordpress_data
```

The output must contain `/home/mobullad/data/wordpress`.

### Is the database populated?

```sh
docker exec -it mariadb mariadb -u wpuser -p wordpress
```

Paste the password from `secrets/db_password.txt`, then:

```sql
SHOW TABLES;
SELECT user_login, user_email FROM wp_users;
```

You should see the WordPress tables and the two accounts.

### Does the data really persist?

Publish a post, then:

```sh
make down
make
```

Reload the site: the post is still there. It survives a reboot of the
virtual machine the same way.

## 6. Common problems

| Symptom                              | Cause and fix                                                     |
| ------------------------------------ | ----------------------------------------------------------------- |
| The browser cannot resolve the domain | `/etc/hosts` is missing the entry. Run `make hosts`.              |
| `502 Bad Gateway`                     | php-fpm is not answering. `docker logs wordpress`.                |
| The WordPress installation wizard appears | The site was never installed, usually because MariaDB was unreachable. `make fclean && make`. |
| `wordpress` restarts in a loop        | It cannot reach the database. Check `docker logs mariadb`, and that the password in `secrets/db_password.txt` matches the one the database was created with. |
| `Permission denied` on `/home/mobullad/data` | The directories belong to another user. `sudo chown -R $USER /home/mobullad/data`. |
| The certificate warning comes back    | Normal. It is self-signed and is not meant to be trusted by a certificate authority. |
