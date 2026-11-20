#!/bin/bash
# try-to-delete-stack.sh
# Try to delete a protected stack and read the error.
# WARNING: without protection this WOULD delete the stack and everything
# it has created. The script checks the flag first and stops unless it is true.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- Settings (change it if your stack has another name) -----------------
STACK=${PREFIX}-data   # the protected stack

FLAG=$(aws cloudformation describe-stacks \
  --stack-name "$STACK" \
  --query 'Stacks[0].EnableTerminationProtection' \
  --output text)

echo "EnableTerminationProtection: $FLAG"

if [ "$FLAG" != "True" ] && [ "$FLAG" != "true" ]; then
  echo "Protection is not on. Stopping, nothing was deleted."
  exit 1
fi

# Expected: an error saying that the stack cannot be deleted while
# termination protection is enabled
aws cloudformation delete-stack \
  --stack-name "$STACK"

# The stack should be unchanged (same status as before)
aws cloudformation describe-stacks \
  --stack-name "$STACK" \
  --query 'Stacks[0].StackStatus'
