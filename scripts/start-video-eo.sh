#!/bin/bash
# script to start the EchoLite EO video streaming service
# 
# Assumes MIPI IMX477 camera is attached to the device at boot. 
# dependencies python3, python3-picamera, ffmpeg
# futher interaction with pistreamer can be done via the shared fifo /tmp/pistreamer 
# example contents from video.conf
# EO_TYPE=IMX477
# EO_PORT=5600
# EO_BITRATE=2000

SUDO=$(test ${EUID} -ne 0 && which sudo)
TUNING_FILE=/usr/local/echopilot/echoliteProxy/477-Pi4.json
TEST_SCRIPT=/usr/local/echopilot/scripts/detect-eo.sh

EOCAMERA=$SUDO $TEST_SCRIPT

if [ $EOCAMERA="imx477" ]; then
    echo "Start EchoLite EO Video Script for $PLATFORM"
    # Start pistreamer, but direct to local host. echoliteProxy will change the endpoint ip using echo "ip address" > /tmp/pistreamer once it knows the endpoint
    # run in daemon mode so this cleanly exits
    # $SUDO /usr/local/echopilot/echoliteProxy/pistreamer.py 127.0.0.1 ${EO_PORT} ${EO_BITRATE} ${TUNING_FILE} --daemon
    $SUDO /usr/local/echopilot/echoliteProxy/pistreamer_v2.py --gcs_ip 127.0.0.1 --gcs_port ${EO_PORT} --bitrate ${EO_BITRATE} --config_file ${TUNING_FILE}
else
    echo "Error: No EO camera found, not starting pistreamer!"
    exit 0
fi



