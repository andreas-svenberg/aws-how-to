#!/usr/bin/env bash
# curl-with-and-without-cookie.sh
# Show the difference between curl without and with the stickiness cookie.
# Requires which-server.php from guide 23 on the shared storage.
# Usage: bash curl-with-and-without-cookie.sh            (looks up ${PREFIX}-alb)
#        bash curl-with-and-without-cookie.sh <alb-dns>  (uses the name you give)

# The path to the page, the same as in the browser after the DNS name.
# Change it to match your shared folder.
PAGE_PATH="shared/which-server.php"

ALB_DNS="$1"
if [ -z "$ALB_DNS" ]; then
  if [ -z "$PREFIX" ]; then
    echo "Set PREFIX (for example export PREFIX=demo) or give the DNS name as an argument."
    exit 1
  fi
  ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names "${PREFIX}-alb" \
    --query 'LoadBalancers[0].DNSName' --output text)
fi
if [ -z "$ALB_DNS" ] || [ "$ALB_DNS" = "None" ]; then
  echo "Could not find the load balancer. Give the DNS name as an argument."
  exit 1
fi
URL="http://$ALB_DNS/$PAGE_PATH"
JAR=cookies.txt
rm -f "$JAR"

echo "--- Without cookie (curl forgets the cookie every time) ---"
for i in 1 2 3 4 5 6; do
  curl -s "$URL"
  echo
done

echo "--- With cookie (-c saves it, -b sends it back) ---"
for i in 1 2 3 4 5 6; do
  curl -s -c "$JAR" -b "$JAR" "$URL"
  echo
done

echo "--- Cookies saved by curl ---"
cat "$JAR"
rm -f "$JAR"
