#!/bin/bash -e

pihole_current=$(pihole -v | grep "Pi-hole" | cut -d ' ' -f 3)
adminlte_current=$(pihole -v | grep "AdminLTE" | cut -d ' ' -f 6)

echo "Uninstalling Speedtest Mod..."

cd /var/www/html
if [ ! -d /var/www/html/org_admin ]; then
    git clone https://github.com/pi-hole/AdminLTE org_admin
    cd org_admin
    git checkout $adminlte_current >/dev/null 2>&1
    cd -
fi
if [ -d /var/www/html/admin ]; then
    rm -rf mod_admin
    mv admin mod_admin
fi
mv org_admin admin

cd /opt/pihole/
if [ ! -d /opt/pihole/org_pihole ]; then
    git clone https://github.com/pi-hole/pi-hole org_pihole
    cd org_pihole
    git checkout $pihole_current >/dev/null 2>&1
    cd -
fi
if [ -d /opt/pihole/pihole ]; then
    rm -rf mod_pihole
    mv pihole mod_pihole
fi
mv org_pihole pihole

echo "Uninstall complete"
