#!/bin/bash

ts_=$(date +%Y%m%d-%H%M%S)

cd /opt/minecraft || exit 1

die() {
   echo "ERROR: $@" >&2
   exit 1
}

backup() {
    echo "## starting backup $ts_"
    zpath_="/mnt/backup/zbackup/backups/minecraft-$ts_"

    tar -c /var/lib/minecraft/ /var/lib/minecraft2/* /opt/minecraft/* \
        | zbackup backup --non-encrypted --threads 2 --silent "$zpath_" \
        || echo "Warning: possible error or file change during zbackup" >&2

    if [ -e "$zpath_" ]; then
        echo "## Success creating zbackup $zpath_ proceeding"
    else
        echo "## ERROR: during zbackup $zpath_, aborting"
        systemctl start minecraft\*.service
        exit 1
    fi
}

mc() {
    systemctl "$1" minecraft.service minecraft2.service
}

upgrade() {
    mc stop
    backup
    MC_VERSION=1.21 /usr/local/bin/papermc-download-latest.sh
    mc start
}

case "$1" in
    "start")
        mc start
        ;;
    "stop")
        mc stop
        ;;
    "status")
        mc status
        ;;
    "backup")
        mc stop
        backup
        ;;
    "upgrade")
        upgrade
        ;;
    *) die "unknown action $1"
        ;;
esac
