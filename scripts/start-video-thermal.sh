#!/bin/bash
# script to start the EchoLite Thermal Video Service
# 
# This script starts gst daemon, and creates the appropriate video pipeline for either the Boson320, Boson640, or EchoTherm 320
# example contents from video.conf
# THERMAL_TYPE=BOSON640
# THERMAL_HOST=192.168.43.1
# THERMAL_PORT=5601
# THERMAL_BITRATE=1000

SUDO=$(test ${EUID} -ne 0 && which sudo)
LOCAL=/usr/local
TEST_SCRIPT=/usr/local/echopilot/scripts/detect-thermal.sh


echo "Start EchoLite Thermal Video Script for $PLATFORM"

# if host is multicast, then append extra

#if [[ "$THERMAL_HOST" =~ ^[2][2-3][4-9].* ]]; then
#    extra_los="multicast-iface=${LOS_IFACE} auto-multicast=true ttl=10"
#fi

#Scale the THERMAL_BITRATE from kbps to bps
# different encoders take different scales, rpi v4l2h264enc takes bps
SCALED_THERMAL_BITRATE=$(($THERMAL_BITRATE * 1000)) 

# First detect what camera is attached, need to make sure echothermd is running or the echotherm won't be detected
if echotherm --status | grep -q "echothermd not running"; then    
    echo "Starting echotherm daemon..."
    
    # Path to the lock file
    LOCK_FILE="/tmp/echothermd.lock"
    # Check if the lock file exists
    if [ -f "$LOCK_FILE" ]; then
        echo "Removing found lock file"
        sudo -u echopilot /usr/local/bin/echothermd --kill
        # Remove the lock file
        rm "$LOCK_FILE"      
    fi
    sudo -u echopilot /usr/local/bin/echothermd
    sleep 3
fi

THERMALCAMERA=$(sudo "$TEST_SCRIPT")

echo "Thermal Camera is ${THERMALCAMERA}"

if [ "$THERMALCAMERA" != "none" ]; then
    # ensure previous pipelines are cancelled and cleared
    set +e
    gstd -f /var/run -l /dev/null -d /dev/null -k
    set -e
    gstd -e -f /var/run -l /var/run/video-stream/gstd.log -d /var/run/video-stream/gst.log
fi

if [ "$THERMALCAMERA" = "boson640" ] || [ "$THERMALCAMERA" = "boson320" ] ; then

    if [ "$THERMALCAMERA" = "boson640" ]; then
        echo "Detected FLIR Boson 640"
        video_devices=$(ls /dev/video*)
        # Loop through each video device and check if it is a FLIR Boson camera
        for device in $video_devices; do
            # Use v4l2-ctl to get the device name
            device_name=$(v4l2-ctl -d $device --info | grep "Model" | awk '{print $3}')        
            # Check if the device name matches FLIR Boson (assuming "boson" is part of the driver name)
            if [[ "$device_name" == *"Boson"* ]]; then
                echo "FLIR Boson camera found at: $device"   
                # create the pipeline thermalsrc
                echo "Creating the thermalSrc pipeline..." 
                gst-client pipeline_create thermalSrc v4l2src device=$device io-mode=mmap ! "video/x-raw,format=(string)I420,width=(int)640,height=(int)512,framerate=(fraction)30/1" ! v4l2h264enc extra-controls="controls,repeat_sequence_header=1,h264_profile=1,h264_level=11,video_bitrate=${SCALED_THERMAL_BITRATE},h264_i_frame_period=30,h264_minimum_qp_value=10" name=thermalEncoder ! "video/x-h264,level=(string)4" ! rtph264pay config-interval=1 pt=96 ! interpipesink name=thermalSrc
                # original pipeline         
                #gst-launch-1.0 v4l2src device=/dev/video0 io-mode=mmap ! "video/x-raw,format=(string)I420,width=(int)640,height=(int)512,framerate=(fraction)30/1" ! v4l2h264enc extra-controls="controls,video_bitrate=2000000" ! "video/x-h264,level=(string)4.2" ! rtph264pay config-interval=1 pt=96 ! udpsink host=192.168.1.59 port=5600 sync=false
                break
            fi
        done
    elif [ "$THERMALCAMERA" = "boson320" ]; then
        echo "Looking for FLIR Boson 320"
        video_devices=$(ls /dev/video*)
        # Loop through each video device and check if it is a FLIR Boson camera
        for device in $video_devices; do
            # Use v4l2-ctl to get the device name
            device_name=$(v4l2-ctl -d $device --info | grep "Model" | awk '{print $3}')        
            # Check if the device name matches FLIR Boson (assuming "boson" is part of the driver name)
            if [[ "$device_name" == *"Boson"* ]]; then
                echo "FLIR Boson camera found at: $device"       
                # create the pipeline thermalSrc
                echo "Creating the thermalSrc pipeline..." 
                gst-client pipeline_create thermalSrc v4l2src device=$device io-mode=mmap ! "video/x-raw,format=(string)I420,width=(int)320,height=(int)256,framerate=(fraction)30/1" ! v4l2h264enc extra-controls="controls,repeat_sequence_header=1,h264_profile=1,h264_level=11,video_bitrate=${SCALED_THERMAL_BITRATE},h264_i_frame_period=30,h264_minimum_qp_value=10" name=thermalEncoder ! "video/x-h264,level=(string)4" ! rtph264pay config-interval=1 pt=96 ! interpipesink name=thermalSrc
                # original pipeline
                # gst-launch-1.0 v4l2src device=$device ! v4l2h264enc extra-controls="controls,video_bitrate=${SCALED_LOS_THERMAL_BITRATE}" name=thermalEncoder ! "video/x-h264,level=(string)4.2" ! rtph264pay config-interval=1 pt=96 ! interpipesink name=thermalsrc
                break
            fi
        done
    fi

elif [ "$THERMALCAMERA" = "echotherm320" ]; then
    echo "Starting pipeline for Echotherm 320"
    #run echothermd to be able to control the echothermcam
    video_devices=$(ls /dev/video*)
    for device in $video_devices; do
        # Use v4l2-ctl to get the device name
        device_name=$(v4l2-ctl -d $device --info | awk '/Card type/ { card_type = substr($0, index($0, ":") + 2) } END {print card_type}')        
        # Check if the device name matches EchoTherm
        echo "Inspecting $device and checking $device_name for EchoTherm or Dummy video"
        if [[ "$device_name" == *"EchoTherm"* || "$device_name" == *"Dummy video"* ]]; then        
            echo "EchoMAV EchoTherm camera found at: $device"       
            # create the pipeline thermalSrc
            echo "Creating the thermalSrc pipeline..."           
            gst-client pipeline_create thermalSrc v4l2src device=$device ! v4l2h264enc extra-controls="controls,repeat_sequence_header=1,h264_profile=1,h264_level=11,video_bitrate=${SCALED_THERMAL_BITRATE},h264_i_frame_period=30,h264_minimum_qp_value=10" name=thermalEncoder ! "video/x-h264,level=(string)4" ! rtph264pay config-interval=1 pt=96 ! interpipesink name=thermalSrc
            # original pipeline
            #gst-launch-1.0 v4l2src device=/dev/video0 ! v4l2h264enc extra-controls="controls,video_bitrate=2000000" ! "video/x-h264,level=(string)4.2" ! rtph264pay config-interval=1 pt=96 ! udpsink host=192.168.1.87 port=5600 sync=false
            break
         fi
    done   
fi

if [ "$THERMALCAMERA" != "none" ]; then
    # start playing the thermalSrc pipeline set up above
    echo "Playing the thermalSrc pipeline..." 
    gst-client pipeline_play thermalSrc

    echo "Creating the thermal pipeline..." 
    gst-client pipeline_create thermal interpipesrc listen-to=thermalSrc block=true is-live=true allow-renegotiation=true stream-sync=compensate-ts ! udpsink sync=false host=127.0.0.1 port=5601 name=thermalSink
fi
# TODO, rather than hard coding the THERMAL HOST, we will latch on to the first GCS connection, and use that

# echoliteProxy will start the thermal pipeline with gst-client pipeline_play thermal

# Notes on the Boson control using rawBoson
# As an example: this sets the camera to black-hot ./rawBoson cB0003 x0 x0 x0 x1, see the palette enum below

# NUC: rawBoson c50007 (note cameras without shutters, this needs to be done when looking at a uniform scene)
# zooming in rawBoson cd0002 x0 x0 x0 x00 x0 x0 x1 x40 x0 x0 x1 x0
# gets the current zoom parameters ./rawBoson cd0003
# will return "00 00 00 00 00 00 01 40 00 00 01 00"
# The first 4 bytes are the "zoom level", min 0x0, max 0x30
# The second 4 are the centerX (0x00000140 = 320)  (center of the 640x512 image), for Boson320 (0x000000A0 = 160)
# The third 4 are center Y (0x00000100 = 256) (center of the 640x512 image), for Boson320 = (0x00000080 = 128)
# Tou get the maximum "zoom index" with this ./rawBoson cd0001
# This will return "00 00 00 30"

# Color Palettes
# FLR_COLORLUT_WHITEHOT = 0
# FLR_COLORLUT_BLACKHOT = 1
# FLR_COLORLUT_RAINBOW = 2
# FLR_COLORLUT_RAINBOW_HC = 3
# FLR_COLORLUT_IRONBOW = 4
# FLR_COLORLUT_LAVA = 5
# FLR_COLORLUT_ARCTIC = 6
# FLR_COLORLUT_GLOBOW = 7
# FLR_COLORLUT_GRADEDFIRE = 8
# FLR_COLORLUT_HOTTEST = 9
# FLR_COLORLUT_ID_END = 10