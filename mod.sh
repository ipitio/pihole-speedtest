#!/bin/bash
LOG_FILE="/var/log/pimod.log"

mod() {
    if [ $EUID != 0 ]; then
        sudo "$0" "$@"
        exit $?
    fi

    if [ -n "$1" ]; then
        case "$1" in
            "in")
                curl -sSLN https://github.com/ipitio/pihole-speedtest/raw/ipitio/install.sh | sudo bash
                ;;
            "up")
                curl -sSLN https://github.com/ipitio/pihole-speedtest/raw/ipitio/update.sh | sudo bash -s -- $2
                ;;
            "un")
                curl -sSLN https://github.com/ipitio/pihole-speedtest/raw/ipitio/uninstall.sh | sudo bash
                ;;
            *)
                echo "Usage: $0 [up [un]|un]"
                exit 1
                ;;
        esac
        if [ $? -eq 0 ]; then
            rm -rf /var/www/html/mod_admin
            rm -f /opt/pihole/webpage.sh.mod
            exit 0
        fi

        echo "$(date) - Something went wrong." | sudo tee -a /var/log/pimod.log
        if [ "$1" == "up" ] || [ "$1" == "un" ]; then
            if [ ! -d /var/www/html/mod_admin ] || [ ! -f /opt/pihole/webpage.sh.mod ]; then
                echo "$(date) - Speedtest Mod is not backed up, did not restore automatically."
            else
                echo "$(date) - Restoring files..."
                cd /var/www/html
                rm -rf admin
                mv mod_admin admin
                cd /opt/pihole/
                mv webpage.sh.mod webpage.sh
                echo "$(date) - Files restored."
            fi
        fi
        echo "$(date) - Please try again or try manually."
    fi
}

mod "$@" 2>&1 | sudo tee -- "$LOG_FILE"