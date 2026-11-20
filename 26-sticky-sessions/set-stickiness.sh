#!/usr/bin/env bash
# set-stickiness.sh
# Turn duration-based stickiness on or off for a target group.
# Usage: bash set-stickiness.sh on    (lb_cookie, 60 seconds)
#        bash set-stickiness.sh off
# Run in a terminal or CloudShell.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- Settings (change them if yours are different) -----------------------
TG_NAME=${PREFIX}-web-tg   # the target group behind the load balancer
DURATION=60                # seconds, allowed range 1 second to 7 days

TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
if [ -z "$TG_ARN" ] || [ "$TG_ARN" = "None" ]; then
  echo "Target group $TG_NAME not found."
  exit 1
fi
echo "Target group: $TG_ARN"

case "$1" in
  on)
    aws elbv2 modify-target-group-attributes \
      --target-group-arn "$TG_ARN" \
      --attributes \
        Key=stickiness.enabled,Value=true \
        Key=stickiness.type,Value=lb_cookie \
        Key=stickiness.lb_cookie.duration_seconds,Value=$DURATION \
      --output table
    ;;
  off)
    aws elbv2 modify-target-group-attributes \
      --target-group-arn "$TG_ARN" \
      --attributes Key=stickiness.enabled,Value=false \
      --output table
    ;;
  *)
    echo "Usage: bash set-stickiness.sh on|off"
    exit 1
    ;;
esac
