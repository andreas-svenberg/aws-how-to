#!/usr/bin/env bash
# add-maintenance-rule.sh
# Add a fixed-response rule to the HTTP:80 listener of the load balancer:
# path /maintenance returns 503 with a short HTML page.
# Run in the same folder as maintenance-response.json (terminal or CloudShell).
# Delete the console rule from step 1 first: two rules cannot share priority 10.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- Settings (change them if yours are different) -----------------------
ALB_NAME=${PREFIX}-alb   # the load balancer
PRIORITY=10              # must not be used by another rule on the listener

# Git Bash would otherwise rewrite /maintenance into a Windows path.
export MSYS_NO_PATHCONV=1

LB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query 'LoadBalancers[0].DNSName' --output text)

# Single quotes around the query because of the backticks.
LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$LB_ARN" \
  --query 'Listeners[?Port==`80`].ListenerArn' --output text)
if [ -z "$LISTENER_ARN" ] || [ "$LISTENER_ARN" = "None" ]; then
  echo "No HTTP:80 listener found on $ALB_NAME."
  exit 1
fi
echo "Listener: $LISTENER_ARN"

# --- 1. Create the rule ---------------------------------------------------
RULE_ARN=$(aws elbv2 create-rule \
  --listener-arn "$LISTENER_ARN" --priority "$PRIORITY" \
  --conditions Field=path-pattern,Values=/maintenance \
  --actions file://maintenance-response.json \
  --query 'Rules[0].RuleArn' --output text)
echo "Rule: $RULE_ARN"

# --- 2. Test: /maintenance gives 503, the start page works as before -----
curl -i "http://$ALB_DNS/maintenance"
echo
curl -s -o /dev/null -w "Start page: %{http_code}\n" "http://$ALB_DNS/"

# --- 3. Clean up (run by hand when you are done) -------------------------
echo "To remove the rule:"
echo "aws elbv2 delete-rule --rule-arn $RULE_ARN"
