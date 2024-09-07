#!/bin/bash
# usage:
#   ensure-pistreamer.sh
#
# Ensure that all pistreamer dependences are met

DRY_RUN=false
SUDO=$(test ${EUID} -ne 0 && which sudo)

$SUDO apt install -y python3-libcamera libcamera-apps
$SUDO apt install -y python3-picamera2
$SUDO apt install -y ffmpeg
