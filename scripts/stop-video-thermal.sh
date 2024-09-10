#!/bin/bash
# script to stop the EchoLite Thermal video service

 # Path to the lock file
LOCK_FILE="/tmp/echothermd.lock"

echo "Killing echothermd"
sudo -u echopilot /usr/local/bin/echothermd --kill

# Check if the lock file exists
if [ -f "$LOCK_FILE" ]; then        
    # Remove the lock file
    echo "Found and removing lock file"
    rm "$LOCK_FILE"      
fi

gst-client pipeline_stop thermalSrc
gst-client pipeline_stop thermal

gst-client pipeline_delete thermalSrc
gst-client pipeline_delete thermal

set +e
gstd -f /var/run -l /dev/null -d /dev/null -k
set -e
