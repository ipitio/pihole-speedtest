#!/bin/bash -e
LOG_FILE="/var/log/pimod.log"

up() {
    pihole_latest=$(curl -s https://api.github.com/repos/ipitio/pi-hole/releases/latest | grep tag_name | cut -d '"' -f 4)
    adminlte_latest=$(curl -s https://api.github.com/repos/ipitio/AdminLTE/releases/latest | grep tag_name | cut -d '"' -f 4)
    pihole_ftl_latest=$(curl -s https://api.github.com/repos/pi-hole/FTL/releases/latest | grep tag_name | cut -d '"' -f 4)

    pihole_current=$(pihole -v | grep "Pi-hole" | cut -d ' ' -f 3)
    adminlte_current=$(pihole -v | grep "AdminLTE" | cut -d ' ' -f 6)
    pihole_ftl_current=$(pihole -v | grep "FTL" | cut -d ' ' -f 6)

    if [[ ! "$pihole_current" < "$pihole_latest" ]] && [[ ! "$adminlte_current" < "$adminlte_latest" ]] && [[ ! "$pihole_ftl_current" < "$pihole_ftl_latest" ]] && [[ "$1" != "un" ]]; then
        echo "$(date) - Pi-hole is already up to date"
        exit 0
    fi

    curl -sSLN https://github.com/ipitio/pihole-speedtest/raw/ipitio/uninstall.sh | sudo bash -s -- d
    PIHOLE_SKIP_OS_CHECK=true sudo -E pihole -up

    if [ "$1" == "un" ]; then
        exit 0
    fi

    echo "$(date) - Installing Speedtest Mod..."

    cd /var/www/html
    rm -rf new_admin
    git clone https://github.com/ipitio/AdminLTE new_admin
    cd /opt/pihole/
    wget -O webpage.sh.mod https://github.com/ipitio/pi-hole/raw/ipitio/advanced/Scripts/webpage.sh
    chmod +x webpage.sh.mod
    cp webpage.sh webpage.sh.org
    mv webpage.sh.mod webpage.sh
    cd -
    rm -rf pihole_admin
    rm -rf admin_bak
    rm -rf org_admin
    mv admin org_admin
    mv new_admin admin

    pihole updatechecker local

    echo "$(date) - Install complete"
}