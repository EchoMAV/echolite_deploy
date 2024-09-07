#!/bin/bash
# 
# This starts echoliteProxy

SUDO=$(test ${EUID} -ne 0 && which sudo)
LOCAL=/usr/local

echo "Starting echoliteProxy"

cd ${LOCAL}/echopilot/echoliteProxy/ && ./echoliteProxy start
