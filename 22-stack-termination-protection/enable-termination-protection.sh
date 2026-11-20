#!/bin/bash
# enable-termination-protection.sh
# Turn on termination protection for a stack and check it.
# Run in a terminal or CloudShell.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- Settings (change it if your stack has another name) -----------------
STACK=${PREFIX}-data   # the stack to protect

# Turn on termination protection (answers with the StackId)
aws cloudformation update-termination-protection \
  --enable-termination-protection \
  --stack-name "$STACK"

# Check the flag (should print true)
aws cloudformation describe-stacks \
  --stack-name "$STACK" \
  --query 'Stacks[0].EnableTerminationProtection'

# To turn it off again (needed before the stack can be deleted):
# aws cloudformation update-termination-protection \
#   --no-enable-termination-protection \
#   --stack-name "$STACK"
