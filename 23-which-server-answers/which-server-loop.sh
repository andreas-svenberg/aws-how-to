#!/usr/bin/env bash
# which-server-loop.sh
# Ask the load balancer six times which server answers.
# Run in a terminal on your own computer, or in CloudShell.
# Usage: bash which-server-loop.sh             (looks up ${PREFIX}-alb)
#        bash which-server-loop.sh <alb-dns>   (uses the name you give)

# The path to the page, the same as in the browser after the DNS name.
# Change it to match your shared folder.
PAGE_PATH="shared/which-server.php"

ALB_DNS="$1"
if [ -z "$ALB_DNS" ]; then
  if [ -z "$PREFIX" ]; then
    echo "Set PREFIX (for example PREFIX=demo) or give the DNS name as an argument."
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
echo "Load balancer: $ALB_DNS"

# Six requests, one answer per line
for i in 1 2 3 4 5 6; do
  curl -s "http://$ALB_DNS/$PAGE_PATH"
  echo
done
