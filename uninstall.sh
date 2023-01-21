#!/bin/bash -e

pihole_current=$(pihole -v | grep "Pi-hole" | cut -d ' ' -f 3)
adminlte_current=$(pihole -v | grep "AdminLTE" | cut -d ' ' -f 6)
pihole_ftl_current=$(pihole -v | grep "FTL" | cut -d ' ' -f 6)

echo "Reverting files..."

cd /var/www/html
if [ -d /var/www/html/admin ]; then
    rm -rf mod_admin
    mv admin mod_admin
fi
if [ -d /var/www/html/org_admin ]; then
    mv org_admin admin
else
    git clone https://github.com/pi-hole/AdminLTE admin
    cd admin
    git checkout $adminlte_current >/dev/null 2>&1
fi

cd /opt/pihole/
mv webpage.sh webpage.sh.mod
mv version.sh version.sh.mod
if [ -f /opt/pihole/webpage.sh.org ] && [ -f /opt/pihole/version.sh.org ]; then
    mv webpage.sh.org webpage.sh
    mv version.sh.org version.sh
else
    git clone https://github.com/pi-hole/pi-hole /tmp/pihole-revert
    cd /tmp/pihole-revert
    git checkout $pihole_current >/dev/null 2>&1
    mv advanced/Scripts/webpage.sh /opt/pihole/webpage.sh
    mv advanced/Scripts/version.sh /opt/pihole/version.sh
    cd -
    rm -rf /tmp/pihole-revert
    chmod +x webpage.sh
    chmod +x version.sh
fi

echo "Files reverted."