#!/bin/bash

# start SSH
mkdir -p /var/run/sshd
/usr/sbin/sshd

# start redis
redis-server > /dev/null 2>&1 &
sleep 5

# Regenerate the SSH host key
/bin/rm /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Link data directories to /srv/gitlab/data
rm -R /home/git/gitlab/tmp
ln -s /srv/gitlab/data/tmp /home/git/gitlab/tmp
chown -R git /srv/gitlab/data/tmp/
chmod -R u+rwX  /srv/gitlab/data/tmp/

rm -R /home/git/.ssh
ln -s /srv/gitlab/data/ssh /home/git/.ssh
chown -R git:git /srv/gitlab/data/ssh
chmod -R 0700 /srv/gitlab/data/ssh
chmod 0700 /home/git/.ssh

chown -R git:git /srv/gitlab/data/gitlab-satellites
chmod -R ug+rwX,o-rwx /srv/gitlab/data/gitlab-satellites
chmod -R ug-s /srv/gitlab/data/gitlab-satellites

chown -R git:git /srv/gitlab/data/repositories
chmod -R ug+rwX,o-rwx /srv/gitlab/data/repositories
chmod -R ug-s /srv/gitlab/data/repositories

find /srv/gitlab/data/repositories/ -type d -print0 | xargs -0 chmod g+s

cat << EOF > /etc/default/gitlab
export POSTGRESQL_DATABASE="${POSTGRESQL_DATABASE}"
export POSTGRESQL_PASSWORD="${POSTGRESQL_PASSWORD}"
export POSTGRESQL_PORT_5432_TCP_ADDR="${POSTGRESQL_PORT_5432_TCP_ADDR=}"
export POSTGRESQL_PORT_5432_TCP_PORT="${POSTGRESQL_PORT_5432_TCP_PORT=}"
export POSTGRESQL_USERNAME="${POSTGRESQL_USERNAME}"
export GIT_EMAIL_FROM="${GIT_EMAIL_FROM}"
export GIT_EMAIL_SUPPORT="${GIT_EMAIL_SUPPORT=}"
export GIT_HOST="${GIT_HOST}"
EOF

# ==============================================
# === Delete this section if restoring data from previous build ===

#cd /home/git/gitlab
#su git -c "bundle exec rake gitlab:setup force=yes RAILS_ENV=production"
#sleep 5
#su git -c "bundle exec rake db:seed_fu RAILS_ENV=production"

# ================================================================

# remove PIDs created by GitLab init script
rm /home/git/gitlab/tmp/pids/*

# start gitlab
service gitlab start

# keep script in foreground
touch /home/git/gitlab/log/production.log
chown git:git /home/git/gitlab/log/production.log
tail -f /home/git/gitlab/log/production.log
