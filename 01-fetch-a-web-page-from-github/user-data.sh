#!/bin/bash
# User data: runs as root at first boot, so no sudo is needed.
# Installs Apache and fetches index.html from a public GitHub repository.
# Replace the address with the raw address of index.html in your own repository.
RAW_URL="https://raw.githubusercontent.com/<account>/<repo>/main/<path>"

dnf install -y httpd
systemctl enable --now httpd
curl -fsSL -o /var/www/html/index.html "$RAW_URL"
