#!/bin/bash
# Writes a page that shows which instance and availability zone it comes from.
# Note: overwrites /var/www/html/index.html. Any page already there is replaced.
# Run on the server:  sudo bash metadata-page.sh
# Or paste it into user data after the lines that install and start httpd (runs as root there).
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
M=http://169.254.169.254/latest/meta-data
ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" $M/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" $M/placement/availability-zone)
cat > /var/www/html/index.html <<EOT
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Which instance?</title></head>
<body><h1>Which instance?</h1><p>This page comes from instance $ID in zone $AZ.</p></body></html>
EOT
