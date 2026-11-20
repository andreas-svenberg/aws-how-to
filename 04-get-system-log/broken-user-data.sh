#!/bin/bash
# User data with a deliberate typo (httpdd), to practise troubleshooting.
# The install fails, httpd never starts and the page does not show.
# Read the system log in the console, then fix the typo and launch a new instance.
dnf install -y httpdd
systemctl enable --now httpd
echo '<h1>Hello from EC2</h1>' > /var/www/html/index.html
