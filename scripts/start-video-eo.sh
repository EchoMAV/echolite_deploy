#!/bin/bash
# script to start the EchoLite EO video streaming service
# 
# Assumes MIPI IMX477 camera is attached to the device at boot. 
# dependencies python3, python3-picamera, ffmpeg
# futher interaction with pistreamer can be done via the shared fifo /tmp/pistreamer 
# example contents from video.conf
# EO_TYPE=IMX477
# EO_HOST=192.168.1.59
# EO_PORT=5600
# EO_BITRATE=2000

SUDO=$(test ${EUID} -ne 0 && which sudo)
TUNING_FILE=/usr/local/echopilot/echoliteProxy/477-Pi4.json

echo "Start EchoLite EO Video Script for $PLATFORM"

# Start pistreamer, but direct to local host. echoliteProxy will change the endpoint ip using echo "ip address" > /tmp/pistreamer once it knows the endpoint
$SUDO /usr/local/echopilot/echoliteProxy/pistreamer.py 127.0.0.1 ${EO_PORT} ${EO_BITRATE} ${TUNING_FILE} --daemon

