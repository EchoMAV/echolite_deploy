#!/bin/bash
# usage:
#   ensure-pistreamer.sh
#
# Ensure that all pistreamer dependencies are met

DRY_RUN=false
SUDO=$(test ${EUID} -ne 0 && which sudo)
SRC=pistreamer_src
DESTINATION=/usr/local/echopilot/echoliteProxy/

if [ ! -d "$DESTINATION" ]; then
  ${SUDO} mkdir -p "$DESTINATION"
fi

${SUDO} apt install -y python3-libcamera libcamera-apps
${SUDO} apt install -y python3-picamera2
${SUDO} apt install -y ffmpeg
${SUDO} apt install -y python3-opencv
${SUDO} apt install -y python3-numpy

# Remove existing SRC directory if it exists
if [ -d "$SRC" ]; then
  ${SUDO} rm -rf "$SRC"
fi

# Install pistreamer
echo "Cloning PiStreamer..."
git clone https://github.com/EchoMAV/PiStreamer "$SRC"
echo "Copying PiStreamer to ${DESTINATION}..."
${SUDO} cp $SRC/pistreamer.py "$DESTINATION"
${SUDO} chmod +x $DESTINATION/pistreamer.py 
