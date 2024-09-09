# EchoLite Deploy Makefile
# EchoMAV, LLC
# bstinson@echomav.com
# Standard install is make install (requires internet)
# Run make installed while the device has internet. At the end of the configuration, an interactive session will let you set up at static IP address

SHELL := /bin/bash
SN := $(shell hostname)
SUDO := $(shell test $${EUID} -ne 0 && echo "sudo")
.EXPORT_ALL_VARIABLES:

SERIAL ?= $(shell python3 serial_number.py)
LOCAL=/usr/local
LOCAL_SCRIPTS=scripts/start.sh scripts/cockpitScript.sh scripts/temperature.sh scripts/start-video-eo.sh scripts/stop-video-eo.sh scripts/start-video-thermal.sh scripts/stop-video-thermal.sh scripts/serial_number.py scripts/snap.sh scripts/start-edge.sh scripts/detect-thermal.sh scripts/detect-eo.sh
CONFIG ?= /var/local
LIBSYSTEMD=/lib/systemd/system
PKGDEPS ?= v4l-utils build-essential nano nload picocom curl htop modemmanager
INSTALL_SERVICES=temperature.service edge.service video-eo.service video-thermal.service echoliteProxy.service
# optionally exclude some services from auto starting by removing them from below
ENABLE_SERVICES=temperature.service edge.service video-eo.service video-thermal.service echoliteProxy.service
SYSCFG=/usr/local/echopilot/echoliteProxy
DRY_RUN=false
PLATFORM ?= $(shell python3 serial_number.py | cut -c1-4)
SW_LOCATION=sw_driver
N2N_REPO=https://github.com/ntop/n2n.git
N2N_REV=3.1.1

.PHONY = clean dependencies cockpit cellular network enable install provision see uninstall n2n echotherm boson nginx pistreamer updateProxy

default:
	@echo "Please choose an action:"
	@echo ""
	@echo "  install: installs programs and system scripts (requires internet)"
	@echo "  dependencies: ensure all needed software is installed (requires internet)"
	@echo "  cockpit: installs and updates only cockpit (requires internet)"
	@echo "  cellular: installs and updates only cellular"
	@echo "  network: sets up only the network"
	@echo "  see: shows the provisioning information for this system"
	@echo "  uninstall: disables and removes services and files"
	@echo ""
	@echo ""

clean:
	@if [ -d src ] ; then cd src && make clean ; fi

dependencies:	
	@if [ ! -z "$(PKGDEPS)" ] ; then $(SUDO) apt-get install -y $(PKGDEPS) ; fi
	@curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | $(SUDO) bash
	@$(SUDO) apt-get install speedtest

updateProxy:
# it happens frequently that we only want to update echoliteProxy, so this does it for us
# set network to dhcp
# assume user would have used the ./setup-network.sh script below to get interent and pull the repo
#	@$(SUDO) ./setup-network.sh -i eth0 -a dhcp
# stop services
	@( for c in stop disable ; do $(SUDO) systemctl $${c} $(INSTALL_SERVICES) ; done ; true )
	@echo "Installing echoliteProxy files..."
	@[ -d $(LOCAL)/echopilot/echoliteProxy ] || $(SUDO) mkdir $(LOCAL)/echopilot/echoliteProxy
	@$(SUDO) cp -a bin/. $(LOCAL)/echopilot/echoliteProxy/  
	@for s in $(LOCAL_SCRIPTS) ; do $(SUDO) install -Dm755 $${s} $(LOCAL)/echopilot/$${s} ; done
	@$(SUDO) chmod +x $(LOCAL)/echopilot/echoliteProxy/echoliteProxy || true
	@$(MAKE) --no-print-directory enable
#now setup the network again
	@$(MAKE) --no-print-directory network

cellular:
# run script which sets up nmcli "cellular" connection. Remove --defaults if you want it to be interactive, otherwise it'll use the default ATT APN: Broadband
	@$(SUDO) ./ensure-cellular.sh

network:
# start an interactive session to configure the network
	@$(SUDO) ./static-network.sh

pistreamer:
# install echotherm
	@PLATFORM=$(PLATFORM) ./ensure-pistreamer.sh $(DRY_RUN)	
	@$(SUDO) install -Dm755 477-Pi4.json $(LOCAL)/echopilot/echoliteProxy/.	

echotherm:
# install echotherm
	@$(SUDO) ./ensure-echotherm.sh

boson:
# install boson dependencies
	@$(SUDO) ./ensure-boson.sh

nginx:
# install nginx
	@$(SUDO) ./ensure-nginx.sh 

n2n:
# clone and build n2n
	@if [ -d src ]; then $(SUDO) rm -rf src; else mkdir -p src; fi
	@git clone $(N2N_REPO) -b $(N2N_REV) src
	@( cd ./src && ./autogen.sh && ./configure && make && $(SUDO) make install )
	@for s in $(LOCAL_SCRIPTS) ; do $(SUDO) install -Dm755 $${s} $(LOCAL)/echopilot/$${s} ; done
	
cockpit:
	@$(SUDO) ./ensure-cockpit.sh
	@for s in $(LOCAL_SCRIPTS) ; do $(SUDO) install -Dm755 $${s} $(LOCAL)/echopilot/$${s} ; done

# set up cockpit files
	@echo "Copying cockpit files..."
	@$(SUDO) rm -rf /usr/share/cockpit/telemetry/ /usr/share/cockpit/mavnet-server/ /usr/share/cockpit/video/ /usr/share/cockpit/cellular || true
	@$(SUDO) mkdir -p /usr/share/cockpit/telemetry/
	@$(SUDO) cp -rf ui/telemetry/* /usr/share/cockpit/telemetry/ || true
#@$(SUDO) mkdir -p /usr/share/cockpit/mavnet-server/ 
#@$(SUDO) cp -rf ui/mavnet-server/* /usr/share/cockpit/mavnet-server/ || true
	@$(SUDO) mkdir -p /usr/share/cockpit/video/
	@$(SUDO) cp -rf ui/video/* /usr/share/cockpit/video/ || true
	@$(SUDO) mkdir -p /usr/share/cockpit/cellular
	@$(SUDO) cp -rf ui/cellular/* /usr/share/cockpit/cellular/ || true
	@$(SUDO) cp -rf ui/branding/debian/* /usr/share/cockpit/branding/debian/ || true
	@$(SUDO) cp -rf ui/static/* /usr/share/cockpit/static/ || true	
	@$(SUDO) cp -rf ui/base1/* /usr/share/cockpit/base1/ || true
	@$(SUDO) install -Dm755 version.txt $(LOCAL)/echopilot/.	

disable:
	@( for c in stop disable ; do $(SUDO) systemctl $${c} $(INSTALL_SERVICES) ; done ; true )
	@$(SUDO) nmcli con down cellular ; $(SUDO) nmcli con delete "cellular"

enable:
	@echo "Installing service files..."
	@( for c in stop disable ; do $(SUDO) systemctl $${c} $(INSTALL_SERVICES) ; done ; true )	
	@( for s in $(INSTALL_SERVICES) ; do $(SUDO) install -Dm644 $${s%.*}.service $(LIBSYSTEMD)/$${s%.*}.service ; done ; true )
	@if [ ! -z "$(INSTALL_SERVICES)" ] ; then $(SUDO) systemctl daemon-reload ; fi
	@echo "Enabling services files..."
	@( for s in $(ENABLE_SERVICES) ; do $(SUDO) systemctl enable $${s%.*} ; done ; true )
	@echo ""

install: dependencies	

# install gstd and gst
	$(SUDO) apt update
	@echo "Installing GSTD and GST Interpipe..."
	@PLATFORM=$(PLATFORM) ./ensure-gst.sh $(DRY_RUN)
	@PLATFORM=$(PLATFORM) ./ensure-gstd.sh $(DRY_RUN)	
	
# build and install n2n
	@echo "Installing and configurign N2N..."
	@$(MAKE) --no-print-directory n2n

# install cockpit
	@echo "Installing Cockpit..."
	@$(MAKE) --no-print-directory cockpit

# install echotherm
	@echo "Installing EchoTherm..."
	@$(MAKE) --no-print-directory echotherm

# install boson
	@echo "Installing Boson..."
	@$(MAKE) --no-print-directory boson

# install nginx
	@echo "Installing Nginx..."
	@$(MAKE) --no-print-directory nginx

# set up folders used by echoliteProxy
	@echo "Setting up echoliteProxy folders..."
	@[ -d /mnt/data/mission ] || $(SUDO) mkdir -p /mnt/data/mission
	@[ -d /mnt/container ] || $(SUDO) mkdir -p /mnt/container
	@[ -d /mnt/data/tmp_images ] || $(SUDO) mkdir -p /mnt/data/tmp_images
	@[ -d /mnt/container/image ] || $(SUDO) mkdir -p /container/image
	@[ -d /mnt/data/mission/processed_images ] || $(SUDO) mkdir -p /mnt/data/mission/processed_images
	@[ -d $(LOCAL)/echopilot ] || $(SUDO) mkdir -p $(LOCAL)/echopilot

# install any UDEV RULES
	@echo "Installing UDEV rules..."
	@for s in $(RULES) ; do $(SUDO) install -Dm644 $${s%.*}.rules $(UDEVRULES)/$${s%.*}.rules ; done
	@if [ ! -z "$(RULES)" ] ; then $(SUDO) udevadm control --reload-rules && udevadm trigger ; fi

# install LOCAL_SCRIPTS
	@echo "Installing local scripts..."
	@for s in $(LOCAL_SCRIPTS) ; do $(SUDO) install -Dm755 $${s} $(LOCAL)/echopilot/$${s} ; done

# stop and disable services
	@echo "Disabling running services..."
	-@for c in stop disable ; do $(SUDO) systemctl $${c} $(INSTALL_SERVICES) ; done ; true

# install echoliteProxy files
	@echo "Installing echoliteProxy files..."
	@[ -d $(LOCAL)/echopilot/echoliteProxy ] || $(SUDO) mkdir $(LOCAL)/echopilot/echoliteProxy
	@$(SUDO) cp -a bin/. $(LOCAL)/echopilot/echoliteProxy/ || true 
# The baseline configuration files are including in this folder including video.conf
	@$(SUDO) chmod +x $(LOCAL)/echopilot/echoliteProxy/echoliteProxy || true

# install pistreamer
	@echo "Installing Pi Streamer..."
	@$(MAKE) --no-print-directory pistreamer

# install services and enable them
	@$(MAKE) --no-print-directory enable

# install cellular
	@echo "Setting up cellular connection..."
	@$(MAKE) --no-print-directory cellular

# provision the network
	@echo "Starting interactive session to set up the network..."
	@$(MAKE) --no-print-directory network

# provision n2n
	@$(SUDO) python3 n2nConfigure.py --interactive --start

# cleanup and final settings
	@echo "Final cleanup..."
	@$(SUDO) chown -R echopilot /usr/local/echopilot
	@$(SUDO) systemctl stop nvgetty &>/dev/null || true
	@$(SUDO) systemctl disable nvgetty &>/dev/null || true
	@$(SUDO) usermod -aG dialout echopilot
	@$(SUDO) usermod -aG tty echopilot
	@echo "Please access the web UI to change settings..."
	@echo "Please reboot now to complete the installation..."

see:
	$(SUDO) cat $(SYSCFG)/echoliteProxy.conf
#   mavnet conf not applicable yet
#	$(SUDO) cat $(SYSCFG)/mavnet.conf
	$(SUDO) cat $(SYSCFG)/video.conf
	$(SUDO) cat $(SYSCFG)/edge.conf
	@echo -n "Cellular APN is: "
	@$(SUDO) nmcli con show cellular | grep gsm.apn | cut -d ":" -f2 | xargs


uninstall:
	@$(MAKE) --no-print-directory disable
	@( for s in $(INSTALL_SERVICES) ; do $(SUDO) rm $(LIBSYSTEMD)/$${s%.*}.service ; done ; true )
	@if [ ! -z "$(INSTALL_SERVICES)" ] ; then $(SUDO) systemctl daemon-reload ; fi
	$(SUDO) rm -f $(SYSCFG)


