# Echomav Deployment for the EchoLite Quadcopters based on the EchoPilot SBX Hardware 

## Using an IP Radio and Fermion (IMX477) + Boson/EchoTherm camera
Radio Options
   - [x] [HereLink **Do not use telemetry, only Power + Ethernet**]
   - [x] [Do not use telemetry, only Power + Ethernet]
   - [x] [e.g. PMDDL2450, pMDDL1624]
   - [x] []

No specific radio configuration is required, other than the radios must be on the same subnet and provisioned appropriately to allow UDP traffic between the air and ground radios.  

Note that in this configuration, echoliteProxy is used to handle telemetry routing over the IP radio, so the telemtry cable should **NOT** be connected to the hHrelink, on the Ethernet. echoliteProxy also acts as a MAVLink-compatible camera manager for the Fermion, ensuring that the GCS receives the stream and is able to control the cameras.

## Dependencies

The device MUST have an internet connection.  
All dependencies will be installed automatically by during a `make install`.

## Installation

To perform an initial install, establish an internet connection and clone the repository.
You will issue the following commands:
```
cd $HOME
git clone https://github.com/echomav/echolite_deploy.git
cd echolite_deploy
make install
```

To configure your system, edit the following files in `/usr/local/echopilot/echoliteProxy/`  
- mavnet.conf - mavnet key, serial number    
- video.conf - video server information  
- echoliteProxy.conf - telemetry related information
- appsettings.json - app related configuration, sensors onboard, gimbal ip address, gcs_passthru variable, default param values, etc.  

## Supported Platforms
These platforms are supported/tested:


 * Raspberry PI
   - [x] [Raspbian Bookworm 64 bit)](https://www.raspberrypi.org/downloads/raspbian/)
 * Jetson Nano
   - [ ] [Jetpack 5.x]

