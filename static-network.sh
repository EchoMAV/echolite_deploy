#!/bin/bash
# EchoMAV, LLC
# This script sets up a static network on the EchoPilot SBX using NetworkManager (nmcli)
# It will prompt the user for the radio type, then populate a default IP based on mac address
# usage: static-network.sh
# An alias is also added to the interface with the value of BACKDOOR_ADDR

IP_PREFIX_MICROHARD="172.20"
IP_PREFIX_HERELINK="192.168.144"
BACKDOOR_ADDR="172.20.154.0/24"
PROMPTINPUT=false
sigterm_handler() { 
  echo "Shutdown signal received."
  exit 1
}

function interactive {
	local result
	read -p "${2}? ($1) " result
	if [ -z "$result" ] ; then result=$1 ; elif [ "$result" == "*" ] ; then result="" ; fi
	echo $result
}


## Setup signal trap
trap 'trap " " SIGINT SIGTERM SIGHUP; kill 0; wait; sigterm_handler' SIGINT SIGTERM SIGHUP

SUDO=$(test ${EUID} -ne 0 && which sudo)

ifconfig eth0 &> /dev/null
if [ $? -ne 0 ] 
        then 
        echo "ERROR: Failed to get information for interface eth0, does it really exist?"
        echo ""
        echo "Here is output of ip link show:"
        ip link show
        exit 1 
fi
# Get the mac address
MAC_ADDRESS=$(ifconfig eth0 | awk '/ether/ {print $2}')

OCT1DEC=$((0x`ifconfig eth0 | awk '/ether/ {print $2}' | awk '{split($0,a,"[:]"); print a[5]}'`))
OCT2DEC=$((0x`ifconfig eth0 | awk '/ether/ {print $2}' | awk '{split($0,a,"[:]"); print a[6]}'`))

echo "MAC address for eth0 is $MAC_ADDRESS";

if ! [[ $OCT1DEC =~ ^[0-9]{1,3} && $OCT2DEC =~ ^[0-9]{1,3} ]] ; then
        echo "Error: Failure calculating the target IP address" >&2; exit 1
fi

echo "Which radio will be installed in this aircraft?:"
echo "M. Microhard"
echo "H. Herelink"

# Prompt user for input
read -p "Enter your choice (M or H): " choice

# Respond based on the user's choice
if [[ "$choice" == "M" || "$choice" == "m" ]]; then
        echo "Configuring for Microhard..."
        HOST="$IP_PREFIX_MICROHARD.$OCT1DEC.$OCT2DEC";
        NETMASK=16;

    # Insert commands or configuration steps for Microhard here
elif [[ "$choice" == "H" || "$choice" == "h" ]]; then
        echo "Configuring for Herelink..."
        # Check if OCT2DEC is equal to 10 or 11, and add 2 if true. 192.168.144.10 and .11 are reserved
        if [ "$OCT2DEC" -eq 10 ] || [ "$OCT2DEC" -eq 11 ]; then
                OCT2DEC=$((OCT2DEC + 2))
        fi
        HOST="$IP_PREFIX_HERELINK.$OCT2DEC";
        NETMASK=24;
        #echo "Note for Herelink radios, IP values can be 192.168.144.X/24, but 192.168.144.10 and 192.168.144.11 cannot be used";
        # Insert commands or configuration steps for Herelink here
else
    echo "Invalid choice. Please run the script again and select 1 or 2."
    exit 1
fi



IFACE="eth0"
echo "The suggested IP for thie device is shown below, please edit or press enter to continue."
IP_INPUT=$(interactive "${HOST}/${NETMASK}" "IPv4 Address with Netmask")
# GATEWAY=$(interactive "172.20.100.100" "IPv4 Gateway")
# no gateway for now, as we want the cellular to provide gateway 
GATEWAY=""

# validate ip address
if [[ ! $IP_INPUT =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,3}$ ]]; then
    echo "ERROR! Invalid IP Address, should be x.x.x.x/y where y is the subnet mask" >&2; exit 1
fi
HOST=$(echo ${IP_INPUT} | cut -d/ -f 1);
NETMASK=$(echo ${IP_INPUT} | cut -d/ -f 2);

echo "Configuring ${IFACE} with the provided static IP address ${HOST}/${NETMASK}";
   
# check if there is a connection called Wired connection 1", if so take it down and delete

state=$(nmcli -f GENERAL.STATE c show "Wired connection 1" 2>/dev/null)
if [[ "$state" == *activated* ]] ; then         # take the interface down
        $SUDO nmcli c down "Wired connection 1"
fi
exist=$(nmcli c show "Wired connection 1" 2>/dev/null)
if [ ! -z "$exist" ] ; then     # delete the interface if it exists
        echo "Removing Wired connection 1..."
        $SUDO nmcli c delete "Wired connection 1"
fi

# check if there is already an interface called static-$IFACE, if so take down and delete
state=$(nmcli -f GENERAL.STATE c show "static-$IFACE" 2>/dev/null)
if [[ "$state" == *activated* ]] ; then         # take the interface down
        $SUDO nmcli c down "static-$IFACE"
fi
exist=$(nmcli c show "static-$IFACE" 2>/dev/null)
if [ ! -z "$exist" ] ; then     # delete the interface if it exists
        $SUDO nmcli c delete "static-$IFACE"
fi

echo "Creating new connection static-$IFACE..."
$SUDO nmcli c add con-name "static-$IFACE" ifname $IFACE type ethernet ip4 $HOST/$NETMASK

# if gateway was provided, add that info to the connection
if [[ "$GATEWAY" == *.* ]]
then
    echo "Defining gateway ${GATEWAY}...";
    $SUDO nmcli c mod "static-$IFACE" ifname $IFACE gw4 $GATEWAY 
fi

# add backdoor ip address
$SUDO nmcli c mod "static-$IFACE" +ipv4.addresses "$BACKDOOR_ADDR"

# disable ipv6
$SUDO nmcli c mod "static-$IFACE" ipv6.method "disabled"

# bring up the interface
$SUDO nmcli c up "static-$IFACE"

# Set mcast routes
$SUDO nmcli con mod "static-$IFACE" +ipv4.routes "224.0.0.0/8"
$SUDO nmcli con mod "static-$IFACE" +ipv4.routes "239.0.0.0/8"

# change hostname
#echo "Setting hostname to EchoMAV-SBX...";
#echo "EchoMAV-SBX" > /tmp/$$.hostname
#$SUDO install -Dm644 /tmp/$$.hostname /etc/hostname
#$SUDO hostname "EchoMAV-SBX"

echo "";
echo "Static Ethernet Configuration Successful! Interface $IFACE is set to $HOST/$NETMASK"
echo ""
