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
LOCAL=/usr/local

echo "Start EchoLite EO Video Script for $PLATFORM"

# Start pistreamer
python3 pistreamer.py ${EO_HOST} ${EO_PORT} ${EO_BITRATE}

