#!/bin/bash
# usage:
#   ensure-nginx.sh
#
# This script ensures that nginx it installed and setup. On the EchoLite, nginix is used to host the camera definition file for download over http port 8080

DRY_RUN=false
LOCAL=/usr/local
SUDO=$(test ${EUID} -ne 0 && which sudo)
NGINXCFG=/etc/nginx/sites-available/default

$SUDO apt-get install -y nginx

if ! grep -q "listen 8080" $NGINXCFG; then
    # Change the port to 8080 and restart
    echo "Changing the listening port for nginx to 8080"
    $SUDO sed -i 's/listen 80 /listen 8080 /g; s/listen \[::\]:80 /listen \[::\]:8080 /g' /etc/nginx/sites-available/default    
else
    echo "Nginx is already set up to listen on 8080"
fi

# Check if "autoindex on;" is already in the file
if ! grep -q "autoindex on;" $NGINXCFG; then
  # Insert "autoindex on;" in the location block if not present
  $SUDO sed -i '/^[^#]*location \/ {/a\ \ \ \ autoindex on;\n\ \ \ \ autoindex_exact_size off;\n\ \ \ \ autoindex_localtime on;' "$NGINXCFG"
  echo "'autoindex on;' has been added."
else
  echo "'autoindex on;' is already present."
fi   

echo "Restarting nginx..."
$SUDO systemctl restart nginx

echo "Copying camera definition(s) to /var/www/html/camera_definitions/..."
$SUDO mkdir -p /var/www/html/camera_definitions
$SUDO cp camera_definitions/*.xml /var/www/html/camera_definitions/.
echo "Creating video/photo directories..."
$SUDO mkdir -p /var/www/html/videos
$SUDO mkdir -p /var/www/html/photos
