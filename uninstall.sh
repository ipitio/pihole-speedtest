#!/bin/bash -e

pihole_current=$(pihole -v | grep "Pi-hole" | cut -d ' ' -f 3)
adminlte_current=$(pihole -v | grep "AdminLTE" | cut -d ' ' -f 6)

echo "Uninstalling Speedtest Mod..."

cd /opt/pihole/
if [ ! -f /opt/pihole/webpage.sh.org ] || [ ! -f /opt/pihole/version.sh.org ]; then
    git clone https://github.com/pi-hole/pi-hole /tmp/pihole-revert
    cd /tmp/pihole-revert
    git checkout $pihole_current >/dev/null 2>&1
    mv advanced/Scripts/webpage.sh /opt/pihole/webpage.sh.org
    mv advanced/Scripts/version.sh /opt/pihole/version.sh.org
    cd -
    rm -rf /tmp/pihole-revert
    chmod +x webpage.sh.org
    chmod +x version.sh.org
fi
cd /var/www/html
if [ ! -d /var/www/html/org_admin ]; then
    git clone https://github.com/pi-hole/AdminLTE org_admin
    cd org_admin
    git checkout $adminlte_current >/dev/null 2>&1
fi
if [ -d /var/www/html/admin ]; then
    rm -rf mod_admin
    mv admin mod_admin
fi
mv org_admin admin
cd -
cp webpage.sh webpage.sh.mod
cp version.sh version.sh.mod
mv webpage.sh.org webpage.sh
mv version.sh.org version.sh

echo "Uninstall complete"
