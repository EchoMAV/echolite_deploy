#!/bin/bash
# usage:
#   ensure-cockpit.sh
#
# This script ensures that cockpit it installed and setup
# As recommended by cockpit, it enableds the backport repo and uses it to get the latest version

DRY_RUN=false
LOCAL=/usr/local
SUDO=$(test ${EUID} -ne 0 && which sudo)

$SUDO echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/backports.list
$SUDO apt update

# Disable exit on error
set +e
# Try to install the package, but don't return an error
$SUDO apt install -y -t bookworm-backports cockpit
# Check if the installation was successful
if [ $? -ne 0 ]; then
    echo "The install failed, probably due to no bookworm-backports package, Running the standard cockpit install..."
    $SUDO apt install -y cockpit    
fi

# Re-enable exit on error
set -e
# Change the port to 443/80 and restart

$SUDO sed -i 's/9090/443/g' /lib/systemd/system/cockpit.socket
$SUDO sed -i '/ListenStream=80/d' /lib/systemd/system/cockpit.socket
$SUDO sed -i '/ListenStream=443/a ListenStream=80' /lib/systemd/system/cockpit.socket 
$SUDO systemctl daemon-reload
$SUDO systemctl restart cockpit.socket

# Get the current Git branch name
branch_name=$(git rev-parse --abbrev-ref HEAD)

# Write the branch name to version.txt
echo "$branch_name" > version.txt

# We need to add permision for cockpit to restart echoliteProxy.service

sudoers_line="cockpit ALL=(ALL) NOPASSWD: /bin/systemctl restart echoliteProxy.service"

# Check if the line already exists in /etc/sudoers
if sudo grep -q "$sudoers_line" /etc/sudoers; then
    echo "Line already exists in /etc/sudoers. No changes made."
else
    # Use a temporary file to edit sudoers safely
    sudoers_temp=$(mktemp)

    # Copy the current sudoers file to the temp file
    $SUDO cp /etc/sudoers "$sudoers_temp"

    # Append the new line to the temp sudoers file
    echo "$sudoers_line" | sudo tee -a "$sudoers_temp" > /dev/null

    # Validate the temp sudoers file using visudo
    $SUDO visudo -cf "$sudoers_temp"

    # If validation succeeds, replace the original sudoers file
    if [ $? -eq 0 ]; then
        $SUDO cp "$sudoers_temp" /etc/sudoers
        echo "Line successfully added to /etc/sudoers."
    else
        echo "Error: The new sudoers file contains syntax errors. No changes were made."
    fi

    # Clean up the temp file
    rm "$sudoers_temp"
fi

