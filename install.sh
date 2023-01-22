#!/bin/bash -e

if [ -f /usr/local/bin/speedtest-cli ]; then
	echo "$(date) - Removing speedtest-cli..."
	apt-get remove speedtest-cli -y
fi

if [ ! -f /usr/local/bin/pihole ]; then
	echo "$(date) - Installing Pi-hole..."
	curl -sSLN https://install.pi-hole.net | sudo bash
fi

curl -sSLN https://github.com/ipitio/pihole-speedtest/raw/ipitio/uninstall.sh | sudo bash
if [ "$1" == "un" ]; then
	#if [ "$2" == "db" ]; then
	#	echo "$(date) - Removing database..."
	#	rm -f /etc/pihole/pihole-FTL.db
	#fi
	exit 0
fi

if [ "$1" == "up" ]; then
	echo "$(date) - Updating Pi-hole..."
	PIHOLE_SKIP_OS_CHECK=true sudo -E pihole -up
	if [ "$2" == "un" ]; then
		#if [ "$3" == "db" ]; then
		#	echo "$(date) - Removing database..."
		#	rm -f /etc/pihole/pihole-FTL.db
		#fi
		exit 0
	fi
fi

PHP_VERSION=$(php -v | tac | tail -n 1 | cut -d " " -f 2 | cut -c 1-3)
if [ ! -f /usr/lib/$PHP_VERSION/mods-available/sqlite3.so ]; then
	echo "$(date) - Installing sqlite3..."
	apt-get install $PHP_VERSION-sqlite3 -y
fi

if [ ! -f /usr/bin/jq ]; then
	echo "$(date) - Installing jq..."
	apt-get install jq -y
fi

if [ ! -f /usr/bin/speedtest ]; then
	echo "$(date) - Installing speedtest..."
	# https://www.speedtest.net/apps/cli
	curl -sSLN https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
	sudo apt-get install speedtest
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

if [ ! -f /etc/pihole/speedtest.db ]; then
	echo "$(date) - Initializing database..."
	cp scripts/pi-hole/speedtest/speedtest.db /etc/pihole/
fi

pihole updatechecker local

echo "$(date) - Install complete"