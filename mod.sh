#!/bin/bash
LOG_FILE="/var/log/pimod.log"

admin_dir=/var/www/html
curr_wp=/opt/pihole/webpage.sh
last_wp=$curr_wp.old
org_wp=$curr_wp.org

curr_db=/etc/pihole/speedtest.db
last_db=$curr_db.old
db_table="speedtest"
create_table="create table if not exists $db_table (
id integer primary key autoincrement,
start_time integer,
stop_time text,
from_server text,
from_ip text,
server text,
server_dist real,
server_ping real,
download real,
upload real,
share_url text
);"

help() {
    echo "(Re)install Latest Speedtest Mod."
    echo "Usage: sudo $0 [up] [un] [db]"
    echo "up - update Pi-hole (along with the Mod)"
    echo "un - remove the mod (including all backups)"
    echo "db - flush database (restore for a short while after)"
}

setTags() {
    local path=${1-}
    local name=${2-}
    if [ ! -z "$path" ]; then
        cd "$path"
        git fetch origin -q
        git fetch --tags -f -q
        latestTag=$(git describe --tags $(git rev-list --tags --max-count=1))
    fi
    if [ ! -z "$name" ]; then
        localTag=$(pihole -v | grep "$name" | cut -d ' ' -f 6)
        [ "$localTag" == "HEAD" ] && localTag=$(pihole -v | grep "$name" | cut -d ' ' -f 7)
    fi
}

download() {
    local path=$1
    local name=$2
    local url=$3
    local src=${4-}
    local dest=$path/$name
    if [ ! -d $dest ]; then # replicate
        cd "$path"
        rm -rf "$name"
        git clone --depth=1 "$url" "$name"
        setTags "$name" "$src"
        if [ ! -z "$src" ]; then
            if [[ "$localTag" == *.* ]] && [[ "$localTag" < "$latestTag" ]]; then
                latestTag=$localTag
                git fetch --unshallow
            fi
        fi
    else # replace
        setTags $dest
        if [ ! -z "$src" ]; then
            if [ "$url" != "old" ]; then
                git config --global --add safe.directory "$dest"
                git remote -v | grep -q "old" || git remote rename origin old
                git remote -v | grep -q "origin" && git remote remove origin
                git remote add origin $url
            else
                git remote remove origin
                git remote rename old origin
            fi
            git fetch origin -q
        fi
        git reset --hard origin/master
    fi

    git -c advice.detachedHead=false checkout $latestTag
    cd ..
}

isEmpty() {
    db=$1
    if [ -f $db ]; then
        if ! sqlite3 "$db" "select * from $db_table limit 1;" >/dev/null 2>&1 || [ -z "$(sqlite3 "$db" "select * from $db_table limit 1;")" ]; then
            return 0
        fi
    fi
    return 1
}

manageHistory() {
    if [ "${1-}" == "db" ]; then
        if [ -f $curr_db ] && ! isEmpty $curr_db; then
            if [ -z "${2-}" ]; then
                echo "$(date) - Flushing Database..."
                mv -f $curr_db $last_db
            fi
        elif [ -f $last_db ]; then
            echo "$(date) - Restoring Database..."
            mv -f $last_db $curr_db
        fi
        echo "$(date) - Configuring Database..."
        sqlite3 "$curr_db" "$create_table"
    fi
}

install() {
    echo "$(date) - Installing Latest Speedtest Mod (and any missing dependencies)"

    if [ ! -f /usr/local/bin/pihole ]; then
        echo "$(date) - Installing Pi-hole..."
        curl -sSL https://install.pi-hole.net | sudo bash
    fi

    if [ ! -f /etc/apt/sources.list.d/ookla_speedtest-cli.list ]; then
        echo "$(date) - Adding speedtest source..."
        # https://www.speedtest.net/apps/cli
        if [ -e /etc/os-release ]; then
            . /etc/os-release
            local base="ubuntu debian"
            local os=${ID}
            local dist=${VERSION_CODENAME}
            if [ ! -z "${ID_LIKE-}" ] && [[ "${base//\"/}" =~ "${ID_LIKE//\"/}" ]] && [ "${os}" != "ubuntu" ]; then
                os=${ID_LIKE%% *}
                [ -z "${UBUNTU_CODENAME-}" ] && UBUNTU_CODENAME=$(/usr/bin/lsb_release -cs)
                dist=${UBUNTU_CODENAME}
                [ -z "$dist" ] && dist=${VERSION_CODENAME}
            fi
            wget -O /tmp/script.deb.sh https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh >/dev/null 2>&1
            chmod +x /tmp/script.deb.sh
            os=$os dist=$dist /tmp/script.deb.sh
            rm -f /tmp/script.deb.sh
        else
            curl -sSLN https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
        fi
    fi

    local PHP_VERSION=$(php -v | head -n 1 | awk '{print $2}' | cut -d "." -f 1,2)
    local packages="bc sqlite3 php${PHP_VERSION}-sqlite3 jq"
    for package in $packages; do
        if dpkg -s $package >/dev/null 2>&1; then
            packages=$(echo $packages | sed "s/$package//")
        fi
    done
    if ! dpkg -s speedtest >/dev/null 2>&1 && ! dpkg -s speedtest-cli >/dev/null 2>&1; then
        packages="$packages speedtest"
    fi
    if [ ! -z "$(echo $packages | sed 's/ //g')" ]; then
        apt-get install -y $packages
    fi

    if [ -f /usr/local/bin/speedtest ]; then
        rm -f /usr/local/bin/speedtest
        ln -s /usr/bin/speedtest /usr/local/bin/speedtest
    fi

    download /opt mod_pihole https://github.com/arevindh/pi-hole
    download /var/www/html admin https://github.com/arevindh/AdminLTE web
    if [ -f $curr_wp ]; then
        if ! cat $curr_wp | grep -q SpeedTest; then
            cp $curr_wp $org_wp
        fi
        if [ ! -f $last_wp ]; then
            cp $curr_wp $last_wp
        fi
    fi
    cp /opt/mod_pihole/advanced/Scripts/webpage.sh $curr_wp
    chmod +x $curr_wp
    manageHistory db .
    pihole -a -s
    pihole updatechecker local
}

uninstall() {
    if [ -f $curr_wp ] && cat $curr_wp | grep -q SpeedTest; then
        echo "$(date) - Uninstalling Current Speedtest Mod..."

        if [ ! -f $org_wp ]; then
            if [ ! -d /opt/org_pihole ]; then
                download /opt org_pihole https://github.com/pi-hole/pi-hole Pi-hole
            fi
            cd /opt
            cp org_pihole/advanced/Scripts/webpage.sh $org_wp
            rm -rf org_pihole
        fi

        pihole -a -su
        download /var/www/html admin https://github.com/pi-hole/AdminLTE web
        if [ ! -f $last_wp ]; then
            cp $curr_wp $last_wp
        fi
        cp $org_wp $curr_wp
        chmod +x $curr_wp
    fi

    manageHistory ${1-}
}

purge() {
    echo "$(date) - Cleaning up..."
    rm -rf "$curr_wp".*
    rm -rf "$admin_dir"*_admin
    rm -rf "$curr_db".*
    rm -rf "$curr_db"_*
    rm -rf /opt/mod_pihole

    if isEmpty $curr_db; then
        rm -f $curr_db
    fi
}

update() {
    echo "$(date) - Updating Pi-hole..."
    cd $admin_dir/admin
    git reset --hard origin/master
    git checkout master
    PIHOLE_SKIP_OS_CHECK=true sudo -E pihole -up
    if [ "${1-}" == "un" ]; then
        purge
        exit 0
    fi
}

abort() {
    if (($aborted == 1)); then
        exit 1
    fi
    aborted=1

    echo "$(date) - Process Aborting..."

    if [ -f $last_wp ]; then
        cp $last_wp $curr_wp
        chmod +x $curr_wp
        rm -f $last_wp
    fi
    if [ -f $last_db ] && [ ! -f $curr_db ]; then
        mv $last_db $curr_db
    fi
    if [ ! -f $curr_wp ] || ! cat $curr_wp | grep -q SpeedTest; then
        purge
    fi
    if [ -d $admin_dir/admin/.git/refs/remotes/old ]; then
        download $admin_dir admin old web
    fi

    pihole restartdns
    echo "$(date) - Please try again or try manually."
    exit 1
}

commit() {
    echo "$(date) - Cleaning Up..."
    cd $admin_dir/admin
    git remote -v | grep -q "old" && git remote remove old
    rm -f $last_wp
    pihole restartdns
    echo "$(date) - Done!"
    exit 0
}

main() {
    printf "Thanks for using Speedtest Mod!\nScript by @ipitio\n\n"
    local op=${1-}
    if [ "$op" == "-h" ] || [ "$op" == "--help" ]; then
        help
        exit 0
    fi
    if [ $EUID != 0 ]; then
        sudo "$0" "$@"
        exit $?
    fi
    aborted=0
    set -Eeuo pipefail
    trap '[ "$?" -eq "0" ] && commit || abort' EXIT
    trap 'abort' INT TERM ERR

    local db=$([ "$op" == "up" ] && echo "${3-}" || [ "$op" == "un" ] && echo "${2-}" || echo "$op")
    case $op in
    db)
        manageHistory $db
        ;;
    un)
        uninstall $db
        purge
        ;;
    up)
        uninstall $db
        update ${2-}
        install
        ;;
    *)
        install
        ;;
    esac
    exit 0
}

main "$@" 2>&1 | sudo tee -- "$LOG_FILE"
