#!/usr/bin/env bash
#
# YDNS updater script
# Copyright (C) 2013-2017 TFMT UG (haftungsbeschränkt) <support@ydns.io>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


##
# Define your YDNS account details and host you'd like to update.
# In case you'd like to update multiple hosts at once, provide the hosts
# separated by space.
##

YDNS_USER="user@host.xx"
YDNS_PASSWD="secret"
YDNS_HOST="myhost.ydns.eu"
## Store last_ip in the same directory as this script
YDNS_LASTIP_FILE="ydns_last_ip_$YDNS_HOST"
YDNS_IP_HISTORY="YDNS_LASTIP_HISTORY.log"

##
# Don't change anything below.
##
YDNS_UPD_VERSION="20250215.0"

if ! hash curl 2>/dev/null; then
	echo "ERROR: cURL is missing."
	exit 1
fi

usage () {
	echo "YDNS Updater"
	echo ""
	echo "Usage: $0 [options]"
	echo ""
	echo "Available options are:"
	echo "  -h             Display usage"
	echo "  -H HOST        YDNS host to update"
	echo "  -u USERNAME    YDNS username for authentication"
	echo "  -p PASSWORD    YDNS password for authentication"
	echo "  -i INTERFACE   Use the local IP address for the given interface"
	echo "  -v             Display version"
	echo "  -V             Enable verbose output"
	exit 0
}

## Shorthand function to update the IP address
update_ip_address () {
	# if this fails with error 60 your certificate store does not contain the certificate,
	# either add it or use -k (disable certificate check
	ret=

	for host in $YDNS_HOST; do
		ret=`curl --basic \
			-u "$YDNS_USER:$YDNS_PASSWD" \
			--silent \
			https://ydns.io/api/v1/update/?host=${host}\&ip=${current_ip}`
	done

	echo ${ret//[[:space:]]/}
}

## Shorthand function to display version
show_version () {
	echo "YDNS Updater version $YDNS_UPD_VERSION"
	exit 0
}

## Shorthand function to write a message
write_msg () {
	if [ $verbose -ne 1 ]; then
		return
	fi

	outfile=1

	if [ -n "$2" ]; then
		outfile=$2
	fi

	echo "[`date +%Y/%m/%dT%H:%M:%S`] $1" >&$outfile
}

verbose=0
local_interface_addr=
custom_host=

while getopts "hH:i:p:u:vV" opt; do
	case $opt in
		h)
			usage
			;;

		H)
			custom_host="$custom_host $OPTARG"
			;;

		i)
			local_interface_addr=$OPTARG
			;;

		p)
			YDNS_PASSWD=$OPTARG
			;;

		u)
			YDNS_USER=$OPTARG
			;;

		v)
			show_version
			;;

		V)
			verbose=1
			;;
	esac
done

if [ "$custom_host" != "" ]; then
	YDNS_HOST=$custom_host
	YDNS_LASTIP_FILE="ydns_last_ip_${YDNS_HOST// /_}"
fi

if [ "$local_interface_addr" != "" ]; then
	# Retrieve current local IP address for a given interface

    if hash ip 2>/dev/null; then
        current_ip=$(ip addr | awk '/inet/ && /'${local_interface_addr}'/{sub(/\/.*$/,"",$2); print $2}')
    fi
fi

if [ "$current_ip" = "" ]; then
	# Retrieve current public IP address
	# current_ip=`curl --silent https://ydns.io/api/v1/ip`
	# Retrieve current public IP address from '4.ipw.cn'
	current_ip=`curl --silent 4.ipw.cn`
    if [ "$current_ip" = "" ]; then
        write_msg "Error: Unable to retrieve current public IP address." 2
        exit 92
    fi
fi

write_msg "Current IP: $current_ip"

# Get last known IP address that was stored locally
if [ -f "$YDNS_LASTIP_FILE" ]; then
	last_ip=`head -n 1 $YDNS_LASTIP_FILE`
else
	last_ip=""
fi

if [ "$current_ip" != "$last_ip" ]; then
	ret=$(update_ip_address)

	case "$ret" in
		badauth)
			write_msg "YDNS host updated failed: $YDNS_HOST (authentication failed)" 2
			exit 90
			;;

		ok)
			write_msg "YDNS host updated successfully: $YDNS_HOST ($current_ip)"
			echo "$current_ip" > $YDNS_LASTIP_FILE
   			# Write to IP log file.
   			echo -e "\n=============\n" >> $YDNS_IP_HISTORY
      			echo  "`date '+%Y-%m-%d %H:%M:%S'`" >> $YDNS_IP_HISTORY
      			echo "$current_ip" >> $YDNS_IP_HISTORY
			exit 0
			;;

		*)
			write_msg "YDNS host update failed: $YDNS_HOST ($ret)" 2
			exit 91
			;;
	esac
else
	write_msg "Not updating YDNS host $YDNS_HOST: IP address unchanged" 2
fi
