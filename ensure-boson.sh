#!/bin/bash
# usage:
#   ensure-boson.sh
#
# Ensure that all boson dependences are met and https://github.com/FLIR/rawBoson.git is installed

DRY_RUN=false
SUDO=$(test ${EUID} -ne 0 && which sudo)
SRC=boson_src
if [ -d $SRC ]; then $SUDO rm -rf $SRC; else mkdir -p $SRC; fi

git clone https://github.com/FLIR/rawBoson.git $SRC
cd $SRC && $SUDO make 

# copy rawBoson to /usr/local/bin
$SUDO cp rawBoson /usr/local/bin/. 
cd ..
# set permissions for /dev/ttyACM0, which may not exist at the time, so ignore errors

DEVICE="/dev/ttyACM0"
# Check if the device exists currently
if [ -e "$DEVICE" ]; then
    # Change the permissions of the device
    $SUDO chmod a+rwx /dev/ttyACM0
fi


