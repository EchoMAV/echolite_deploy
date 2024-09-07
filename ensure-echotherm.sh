#!/bin/bash
# usage:
#   ensure-echotherm.sh
#
# Ensure that all echotherm dependences are met and echotherm daemon is installed

DRY_RUN=false
SUDO=$(test ${EUID} -ne 0 && which sudo)

if [ -d echotherm_src ]; then $(SUDO) rm -rf echotherm_src; else mkdir -p echotherm_src; fi

git clone https://github.com/EchoMAV/EchoTherm-Daemon.git echotherm_src
cd echotherm_src && $SUDO ./install.sh && $SUDO cp build/echotherm /usr/local/bin/. && cp build/echotherd /usr/local/bin/. && cd ..

