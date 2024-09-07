#!/bin/bash
# script to stop the EchoLite Thermal video service

gst-client pipeline_stop thermalSrc
gst-client pipeline_stop thermal

gst-client pipeline_delete thermalSrc
gst-client pipeline_delete thermal

set +e
gstd -f /var/run -l /dev/null -d /dev/null -k
set -e
