#!/bin/bash
# Ensure the mysql user exists with uid/gid 27, matching the k3s pod's
# runAsUser/runAsGroup in the db-mariadb role snippet. Leap 16's mariadb rpm
# creates the mysql user with a different (distro-assigned) uid, so an
# existing user is explicitly moved to 27 and its files are re-owned below.
getent group mysql >/dev/null || /usr/sbin/groupadd -g 27 -o -r mysql
getent passwd mysql >/dev/null || /usr/sbin/useradd -r -o -g mysql -u 27 -s /bin/false -c "MariaDB server" -d /var/lib/mysql mysql

if [ "$(id -u mysql)" != "27" ]; then
    echo "Adjusting mysql user uid $(id -u mysql) -> 27"
    /usr/sbin/usermod -o -u 27 mysql
fi
if [ "$(id -g mysql)" != "27" ]; then
    echo "Adjusting mysql group gid $(id -g mysql) -> 27"
    /usr/sbin/groupmod -o -g 27 mysql
fi

# Ensure server directories exist and are owned by the mysql user so the
# daemon can write its data and socket. /var/run/mysql and /var/log/mysql are
# the openSUSE mariadb package's default socket/pid and log-error locations
# (from /etc/my.cnf); the k3s pod overrides the socket path but mariadbd and
# mariadb-install-db may still touch the others. /var/lib/mysql-files is the
# secure-file-priv target shipped as an empty directory by the RPM — empty
# directories don't survive the container image build, and mariadbd refuses
# to start when the configured secure-file-priv path is missing.
# Fix ownership of anything that belonged to the mysql user's previous
# (distro-assigned) uid/gid, then make sure the server directories exist.
mkdir -p /var/lib/mysql /run/mysqld /var/run/mysql /var/log/mysql /var/lib/mysql-files
chown -R mysql:mysql /var/lib/mysql /run/mysqld /var/run/mysql /var/log/mysql /var/lib/mysql-files

chmod 0755 /usr/local/bin/start-mariadb