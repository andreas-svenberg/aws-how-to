#!/usr/bin/env bash
# load-test-with-ab.sh
# HTTP load test against a load balancer with ab (ApacheBench).
# Run in CloudShell (Amazon Linux 2023). Installed packages disappear
# when the CloudShell session ends, so step 1 may be needed again.
# Keep the test small and short, and only test your own environment.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- 1. Install ab ---------------------------------------------------------
# Check which package provides ab:
dnf provides /usr/bin/ab
sudo dnf install -y httpd-tools
ab -V

# --- 2. DNS name of the load balancer ------------------------------------
# Change the name if your load balancer is not called <prefix>-alb.
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names "${PREFIX}-alb" \
  --query 'LoadBalancers[0].DNSName' --output text)
echo "Load balancer: $ALB_DNS"

# Check that the start page answers before the test (look for 200)
curl -s -o /dev/null -w "%{http_code}\n" "http://$ALB_DNS/"

# --- 3. The test: 2000 requests, 20 at a time ------------------------------
# The trailing slash in the URL is required by ab.
ab -n 2000 -c 20 "http://$ALB_DNS/"

# Read: Requests per second, Time per request,
#       Failed requests, Non-2xx responses (if shown)
