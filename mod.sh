#!/bin/bash
LOG_FILE="/var/log/pimod.log"

help() {
	echo "(Re)install Latest Speedtest Mod."
	echo "Usage: sudo $0 [up] [un] [db]"
	echo "up - update Pi-hole"
	echo "un - remove the mod"
	echo "db - flush database"
}

setTags() {
	local path=${1-}
	local name=${2-}

	if [ ! -z "$path" ]; then
		cd "$path"
		git fetch --tags -q
		latestTag=$(git describe --tags $(git rev-list --tags --max-count=1))
	fi
	if [ ! -z "$name" ]; then
		localTag=$(pihole -v | grep "$name" | cut -d ' ' -f 6)
		[ "$localTag" == "HEAD" ] && localTag=$(pihole -v | grep "$name" | cut -d ' ' -f 7)
	fi
}

clone() {
	local path=$1
	local dest=$2
	local src=$3
	local name=${4-} # if set, will keep local tag if older than latest

	cd "$path"
	rm -rf "$dest"
	git clone --depth=1 "$src" "$dest"
	setTags "$dest" "$name"
	local rightTag=$latestTag
	if [ ! -z "$name" ]; then
		if [[ "$localTag" == *.* ]] && [[ "$localTag" < "$rightTag" ]]; then
			rightTag=$localTag
			git fetch --unshallow
		fi
	fi
	#git -c advice.detachedHead=false checkout $rightTag
}

refresh() {
	local path=$1
	local name=$2
	local url=$3
	local dest=$path/$name

	if [ ! -d $dest ]; then
		clone $path $name $url
	else
		setTags $dest
		git reset --hard origin/master
		#git -c advice.detachedHead=false checkout $latestTag
	fi
}

download() {
	echo "$(date) - Installing any missing dependencies..."

	if [ ! -f /usr/local/bin/pihole ]; then
		echo "$(date) - Installing Pi-hole..."
		curl -sSL https://install.pi-hole.net | sudo bash
	fi

	if [ -z "${1-}" ] || [ "$1" == "up" ]; then
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
		local PHP_VERSION=$(php -v | tac | tail -n 1 | cut -d " " -f 2 | cut -c 1-3)
		apt-get install -y sqlite3 $PHP_VERSION-sqlite3 jq speedtest-cli- speedtest
		if [ -f /usr/local/bin/speedtest ]; then
			rm -f /usr/local/bin/speedtest
			ln -s /usr/bin/speedtest /usr/local/bin/speedtest
		fi

		echo "$(date) - Downloading Latest Speedtest Mod..."

		refresh /var/www/html mod_admin https://github.com/ipitio/AdminLTE
		refresh /opt mod_pihole https://github.com/ipitio/pi-hole
	fi
}

install() {
	echo "$(date) - Installing Speedtest Mod..."

	cd /var/www/html
	if [ -d /var/www/html/admin ]; then
		rm -rf org_admin
		mv -f admin org_admin
	fi
	cp -r mod_admin admin
	cd /opt
	cp pihole/webpage.sh pihole/webpage.sh.org
	cp mod_pihole/advanced/Scripts/webpage.sh pihole/webpage.sh
	chmod +x pihole/webpage.sh

	if [ ! -f /etc/pihole/speedtest.db ]; then
		echo "$(date) - Creating Database..."
		cp /var/www/html/admin/scripts/pi-hole/speedtest/speedtest.db /etc/pihole/
	fi

	pihole updatechecker local
}

hashFile() {
	md5sum $1 | cut -d ' ' -f 1
}

purge() {
	echo "$(date) - Removing backups..."
	rm -rf /opt/pihole/webpage.sh.*
	rm -rf /var/www/html/*_admin
	rm -rf /etc/pihole/speedtest.db.*
	rm -rf /etc/pihole/speedtest.db_*
	if [ "$(hashFile /etc/pihole/speedtest.db)" == "$(hashFile /var/www/html/admin/scripts/pi-hole/speedtest/speedtest.db)" ]; then
		rm -f /etc/pihole/speedtest.db
	fi
	exit 0
}

update() {
	echo "$(date) - Updating Pi-hole..."
	cd /var/www/html/admin
	git reset --hard origin/master
	git checkout master
	PIHOLE_SKIP_OS_CHECK=true sudo -E pihole -up
	if [ "${1-}" == "un" ]; then
		purge
	fi
}

uninstall() {
	if cat /opt/pihole/webpage.sh | grep -q SpeedTest; then
		echo "$(date) - Uninstalling Current Speedtest Mod..."

		if [ ! -f /opt/pihole/webpage.sh.org ]; then
			clone /opt org_pihole https://github.com/pi-hole/pi-hole Pi-hole
			cp advanced/Scripts/webpage.sh ../pihole/webpage.sh.org
			cd ..
			rm -rf org_pihole
		fi

		if [ ! -d /var/www/html/org_admin ]; then
			clone /var/www/html org_admin https://github.com/pi-hole/AdminLTE web
		fi

		cd /var/www/html
		cp -r org_admin admin
		cd /opt/pihole/
		mv webpage.sh.org webpage.sh
		chmod +x webpage.sh
	fi

	if [ "${1-}" == "db" ]; then
		if [ -f /etc/pihole/speedtest.db ] && [ "$(hashFile /etc/pihole/speedtest.db)" != "$(hashFile /var/www/html/admin/scripts/pi-hole/speedtest/speedtest.db)" ]; then
			echo "$(date) - Flushing Database..."
			mv -f /etc/pihole/speedtest.db /etc/pihole/speedtest.db.old
		elif [ -f /etc/pihole/speedtest.db.old ]; then
			echo "$(date) - Restoring Database..."
			mv -f /etc/pihole/speedtest.db.old /etc/pihole/speedtest.db
		fi
	fi
}

restore() {
	if [ ! -d /var/www/html/${1}_admin ] || [ ! -f /opt/pihole/webpage.sh.${1} ]; then
		echo "$(date) - A restore is not needed or one failed."
	else
		echo "$(date) - Restoring Files..."
		cd /var/www/html
		rm -rf admin
		mv ${1}_admin admin
		cd /opt/pihole/
		mv webpage.sh.${1} webpage.sh
		echo "$(date) - Files Restored"
	fi
}

abort() {
	echo "$(date) - Process Aborted" | sudo tee -a /var/log/pimod.log
	case ${1-} in
	up | un | db)
		restore mod
		;;
	*)
		restore org
		;;
	esac
	pihole restartdns
	echo "$(date) - Please try again or try manually."
	exit 1
}

commit() {
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
	set -Eeuo pipefail
	trap '[ "$?" -eq "0" ] && commit || abort $op' EXIT

	local db=$([ "$op" == "up" ] && echo "${3-}" || [ "$op" == "un" ] && echo "${2-}" || echo "$op")
	download $op
	uninstall $db
	case $op in
	un)
		purge
		;;
	up)
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
