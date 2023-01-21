#!/bin/bash -e

whiptail --title "Pi-hole Speedtest Mod Updater and Uninstaller" --msgbox "Update or Uninstall the Mod. \nSupport : https://github.com/ipitio/pihole-speedtest " 8 78

pihole_latest=$(curl -s https://api.github.com/repos/ipitio/pi-hole/releases/latest | grep tag_name | cut -d '"' -f 4)
adminlte_latest=$(curl -s https://api.github.com/repos/ipitio/AdminLTE/releases/latest | grep tag_name | cut -d '"' -f 4)
pihole_ftl_latest=$(curl -s https://api.github.com/repos/pi-hole/FTL/releases/latest | grep tag_name | cut -d '"' -f 4)

pihole_current=$(pihole -v | grep "Pi-hole" | cut -d ' ' -f 3)
adminlte_current=$(pihole -v | grep "AdminLTE" | cut -d ' ' -f 6)
pihole_ftl_current=$(pihole -v | grep "FTL" | cut -d ' ' -f 6)

if [[ ! "$pihole_current" < "$pihole_latest" ]] && [[ ! "$adminlte_current" < "$adminlte_latest" ]] && [[ ! "$pihole_ftl_current" < "$pihole_ftl_latest" ]] && [[ "$1" != "un" ]]; then
    echo "Pi-hole is already up to date."
    #exit 0
fi

# if user does not want to proceed, exit
if ! ( whiptail --title "Pi-hole Speedtest Mod Updater and Uninstaller" --yesno "Proceed?" 8 78); then
    echo "Update cancelled."
    exit 0
fi

echo "Proceeding..."
curl -sSL https://github.com/ipitio/pihole-speedtest/raw/ipitio/uninstall.sh | tac | tac | sudo bash

#PIHOLE_SKIP_OS_CHECK=true sudo -E pihole -up

if [ "$1" == "un" ]; then
    rm -rf /var/www/html/mod_admin
    rm -f /opt/pihole/webpage.sh.mod
    rm -f /opt/pihole/version.sh.mod
    whiptail --title "Pihole Speedtest Mod" --msgbox "Uninstall complete" 8 78
    exit 0
fi

echo "Updating Speedtest Mod..."
cd /var/www/html
rm -rf pihole_admin
rm -rf admin_bak
rm -rf org_admin
mv admin org_admin
git clone https://github.com/ipitio/AdminLTE admin

#Update latest webpage.sh for speedtest-mod
cd /opt/pihole/
mv webpage.sh webpage.sh.org
wget https://github.com/ipitio/pi-hole/raw/ipitio/advanced/Scripts/webpage.sh
chmod +x webpage.sh

mv version.sh version.sh.org
wget https://github.com/ipitio/pi-hole/raw/ipitio/advanced/Scripts/version.sh
chmod +x version.sh

#Update version info
pihole updatechecker local

whiptail --title "Pihole Speedtest Mod" --msgbox "Update complete" 8 78