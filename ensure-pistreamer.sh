#!/bin/bash
# usage:
#   ensure-pistreamer.sh
#
# Ensure that all pistreamer dependences are met

DRY_RUN=false
SUDO=$(test ${EUID} -ne 0 && which sudo)
SRC=pistreamer_src
DESTINATION=/usr/local/echopilot/echoliteProxy/

if [ ! -d "$DESTINATION" ]; then
  mkdir -p "$DESTINATION"

$SUDO apt install -y python3-libcamera libcamera-apps
$SUDO apt install -y python3-picamera2
$SUDO apt install -y ffmpeg

# Install pistreamer

git clone https://github.com/EchoMAV/PiStreamer $SRC
cd $SRC && $SUDO make 
$SUDO cp pistreamer.py $DESTINATION