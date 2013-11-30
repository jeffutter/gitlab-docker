#!/bin/bash

# start SSH
mkdir -p /var/run/sshd
/usr/sbin/sshd

# start redis
redis-server > /dev/null 2>&1 &
sleep 5

# Run the firstrun script
/srv/gitlab/firstrun.sh

# remove PIDs created by GitLab init script
rm /home/git/gitlab/tmp/pids/*

# start gitlab
service gitlab start

# keep script in foreground
sleep 5
tail -f /home/git/gitlab/log/production.log
