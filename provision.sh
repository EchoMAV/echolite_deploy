#!/bin/bash
# usage:
#   provision.sh filename [--dry-run]
#
# Interactively create/update a systemd service configuration file
#
# TODO: figure out use of an encrypted filesystem to hold the configuration file
# https://www.linuxjournal.com/article/9400

CAMERA_STREAMER=/usr/local/src/camera-streamer
SUDO=$(test ${EUID} -ne 0 && which sudo)
SYSCFG=/usr/local/h31/conf
UDEV_RULESD=/etc/udev/rules.d

CONF=$1
shift
DEFAULTS=false
DRY_RUN=false
while (($#)) ; do
	if [ "$1" == "--dry-run" ] && ! $DRY_RUN ; then DRY_RUN=true ;
	elif [ "$1" == "--defaults" ] ; then DEFAULTS=true ;
	fi
	shift
done

function address_of {
	local result=$(ip addr show $1 | grep inet | grep -v inet6 | head -1 | sed -e 's/^[[:space:]]*//' | cut -f2 -d' ' | cut -f1 -d/)
	echo $result
}

function value_of {
	local result=$($SUDO grep -w $1 $CONF 2>/dev/null | cut -f2 -d=)
	if [ -z "$result" ] ; then result=$2 ; fi
	echo $result
}

# pull default provisioning items from the network.conf (generate it first)
function value_from_network {
	local result=$($SUDO grep $1 $(dirname $CONF)/network.conf 2>/dev/null | cut -f2 -d=)
	if [ -z "$result" ] ; then result=$2 ; fi
	echo $result
}

function interactive {
	local result
	read -p "${2}? ($1) " result
	if [ -z "$result" ] ; then result=$1 ; elif [ "$result" == "*" ] ; then result="" ; fi
	echo $result
}

function contains {
	local result=no
	#if [[ " $2 " =~ " $1 " ]] ; then result=yes ; fi
	if [[ $2 == *"$1"* ]] ; then result=yes ; fi
	echo $result
}

# configuration values used in this script
declare -A config
config[iface]=$(value_from_network IFACE wlan0)

case "$(basename $CONF)" in
	echoliteProxy.conf)
			
		HOST=$(value_of HOST 172.20.1.1)  # $(echo $(address_of ${IFACE}) | cut -f1,2 -d.).255.255)
		PORT=$(value_of PORT 14550)
		LOCAL_SERIAL_NUMBER=$(value_of LOCAL_SERIAL_NUMBER 0001)

		# Get the mac address
		MAC_ADDRESS=$(ifconfig eth0 | awk '/ether/ {print $2}')
		OCT1DEC=$((0x`ifconfig eth0 | awk '/ether/ {print $2}' | awk '{split($0,a,"[:]"); print a[5]}'`))
		OCT2DEC=$((0x`ifconfig eth0 | awk '/ether/ {print $2}' | awk '{split($0,a,"[:]"); print a[6]}'`))
		ATAK_HOST=239.2.$OCT1DEC.$OCT2DEC
		ATAK_PORT=$(value_of ATAK_PORT 6969)
		
		if ! $DEFAULTS ; then
			#IFACE=$(interactive "$IFACE" "UDP Interface for telemetry")
			HOST=$(interactive "$HOST" "UDP IPv4 for telemetry")
			PORT=$(interactive "$PORT" "UDP PORT for telemetry")						
			LOCAL_SERIAL_NUMBER=$(interactive "$LOCAL_SERIAL_NUMBER" "Serial Number for Vehicle")
			ATAK_HOST=$(interactive "$ATAK_HOST" "ATAK Video Endpoint Multicast Group Address")
			ATAK_PORT=$(interactive "$ATAK_PORT" "ATAK Video Endpoint Multicast Group Port")
		fi
        echo "[Service]" > /tmp/$$.env && \
		echo "LOCAL_SERIAL_NUMBER=${LOCAL_SERIAL_NUMBER}" >> /tmp/$$.env && \
        echo "TELEM_LOS=eth0,${HOST}:${PORT}" >> /tmp/$$.env && \
        echo "FMU_SERIAL=/dev/ttyAMA3" >> /tmp/$$.env && \
        echo "FMU_BAUDRATE=500000" >> /tmp/$$.env && \
        echo "ATAK_HOST=${ATAK_HOST}" >> /tmp/$$.env && \
        echo "ATAK_PORT=${ATAK_PORT}" >> /tmp/$$.env && \
        echo "SPARECOT_HOST=172.20.1.3" >> /tmp/$$.env && \
        echo "SPARECOT_PORT=7200" >> /tmp/$$.env
		;;

	

	*)
		# preserve contents or generate a viable empty configuration
		echo "[Service]" > /tmp/$$.env
		;;
esac

if $DRY_RUN ; then
	echo $CONF && cat /tmp/$$.env && echo ""
elif [[ $(basename $CONF) == *.sh ]] ; then
	$SUDO install -Dm755 /tmp/$$.env $CONF
else
	$SUDO install -Dm644 /tmp/$$.env $CONF
fi
rm /tmp/$$.env

ASCII_ART="  ______     _           __  __     __      __
 |  ____|   | |         |  \/  |   /\ \    / /
 | |__   ___| |__   ___ | \  / |  /  \ \  / / 
 |  __| / __| '_ \ / _ \| |\/| | / /\ \ \/ /  
 | |___| (__| | | | (_) | |  | |/ ____ \  /   
 |______\___|_| |_|\___/|_|  |_/_/    \_\/    
"

# Append the ASCII art to the /etc/motd file
$SUDO echo "$ASCII_ART" >> /etc/motd


