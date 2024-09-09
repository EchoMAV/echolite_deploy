#!/bin/bash
# Detect which type of thermal camera is attached, respond with none, boson640, boson320, echotherm320
# For EchoTherm, we assume that echothermd is already running, and therefore we should get a response from echotherm --status

SUDO=$(test ${EUID} -ne 0 && which sudo)
bosonfound=false
echothermfound=false

for device in /dev/video*; do
    if v4l2-ctl -d "$device" --info 2>/dev/null | grep -q "Boson: FLIR Video"; then    
        bosonfound=true
        #echo "FLIR Boson camera detected on $device"    
        v4l2-ctl -d "$device" --list-formats-ext 2>/dev/null | grep "640x512" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "boson640"
        else
            echo "boson320"
        fi            
        break
    fi
done

if echotherm --status | grep -q "echotherm camera connected"; then    
    echothermfound=true
    echo "echotherm320"
fi

if [ "$bosonfound" = false ] && [ "$echothermfound" = false ]; then
    echo "none"
fi
