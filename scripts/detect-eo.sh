#!/bin/bash
# Detect which type of EO camera is attached, respond with none, imx477

SUDO=$(test ${EUID} -ne 0 && which sudo)
imx477found=false

rpicam-vid --list-cameras 2>/dev/null | grep "imx477" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        imx477found=true
        echo "imx477"
    fi

if [ "$imx477found" = false ]; then
    echo "none"
fi
