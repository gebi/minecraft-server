#!/bin/bash

ts_=$(date +%Y%m%d-%H%M%S)

zrepo_="/mnt/backup/zbackup"
zbackups_="$zrepo_/backups"

# backup retention: the newest backup of each of the last N days / ISO weeks / months is kept
keep_daily_="${KEEP_DAILY:-14}"
keep_weekly_="${KEEP_WEEKLY:-12}"
keep_monthly_="${KEEP_MONTHLY:-12}"
# zbackup gc mode: fast | deep
gc_mode_="${GC_MODE:-fast}"
# set PRUNE_DRY_RUN=1 to only show what would be removed
prune_dry_run_="${PRUNE_DRY_RUN:-0}"

cd /opt/minecraft || exit 1

die() {
   echo "ERROR: $*" >&2
   exit 1
}

backup() {
    echo "## starting backup $ts_"
    zpath_="$zbackups_/minecraft-$ts_"

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

prune() {
    local -A days_ weeks_ months_
    local b_ name_ d_ day_ week_ month_ keep_ removed_=0 kept_=0

    echo "## pruning backups in $zbackups_ (daily=$keep_daily_ weekly=$keep_weekly_ monthly=$keep_monthly_)"

    # newest first, only names created by backup() above
    while IFS= read -r b_; do
        name_="${b_##*/}"
        d_="${name_#minecraft-}"
        d_="${d_%-*}"
        day_="$d_"
        week_="$(date -d "$d_" +%G-%V)" || { echo "## WARNING: skipping $name_, unparsable date" >&2; continue; }
        month_="${d_:0:6}"
        keep_=""

        if [[ -z "${days_[$day_]}" ]] && (( ${#days_[@]} < keep_daily_ )); then
            days_[$day_]=1; keep_=1
        fi
        if [[ -z "${weeks_[$week_]}" ]] && (( ${#weeks_[@]} < keep_weekly_ )); then
            weeks_[$week_]=1; keep_=1
        fi
        if [[ -z "${months_[$month_]}" ]] && (( ${#months_[@]} < keep_monthly_ )); then
            months_[$month_]=1; keep_=1
        fi
        # never remove the newest backup
        (( kept_ + removed_ == 0 )) && keep_=1

        if [[ -n "$keep_" ]]; then
            kept_=$((kept_ + 1))
        else
            removed_=$((removed_ + 1))
            if [[ "$prune_dry_run_" == "1" ]]; then
                echo "would remove $name_"
            else
                rm -f -- "$b_"
            fi
        fi
    done < <(find "$zbackups_" -maxdepth 1 -type f -regextype posix-extended \
                -regex '.*/minecraft-[0-9]{8}-[0-9]{6}' | sort -r)

    echo "## kept $kept_ backups, removed $removed_"
    if [[ "$prune_dry_run_" != "1" ]] && (( removed_ > 0 )); then
        echo "## running zbackup gc $gc_mode_"
        zbackup --non-encrypted --silent gc "$gc_mode_" "$zrepo_" \
            || echo "## WARNING: zbackup gc failed" >&2
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
    # prune after the servers are running again, gc can take a while
    prune
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
    "prune")
        prune
        ;;
    *) die "unknown action $1"
        ;;
esac
