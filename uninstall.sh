#!/bin/bash -e

pihole_current=$(pihole -v | grep "Pi-hole" | cut -d ' ' -f 3)
adminlte_current=$(pihole -v | grep "Web" | cut -d ' ' -f 6)
pihole_ftl_current=$(pihole -v | grep "FTL" | cut -d ' ' -f 6)

echo "Reverting files..."

cd /var/www/html
rm -rf mod_admin
mv admin mod_admin
if [ -d /var/www/html/org_admin ]; then
    mv org_admin admin
else
    git clone https://github.com/pi-hole/AdminLTE admin
    cd admin
    git checkout $adminlte_current
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
    git checkout $pihole_current
    mv advanced/Scripts/webpage.sh /opt/pihole/webpage.sh
    mv advanced/Scripts/version.sh /opt/pihole/version.sh
    cd -
    rm -rf /tmp/pihole-revert
    chmod +x webpage.sh
    chmod +x version.sh
fi

echo "Files reverted."
exit 0