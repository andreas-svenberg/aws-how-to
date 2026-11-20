#!/bin/bash
# call-function-url.sh
# Call a Lambda function through its function URL.
# Create the URL in the console first (auth type NONE, demo only).
# Run in a terminal or CloudShell.
# Do not commit the URL anywhere: with NONE anyone who has it can call it.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- Settings (change it if your function has another name) --------------
FN=${PREFIX}-site-check   # the Lambda function with the function URL

# Read the URL of the function
URL=$(aws lambda get-function-url-config \
  --function-name "$FN" \
  --query FunctionUrl --output text)
echo "Function URL: $URL"

# Call it once and show what the function answers
curl -s "$URL"
echo

# Show the resource policy (look for the two statements with Principal *)
aws lambda get-policy \
  --function-name "$FN" \
  --query Policy --output text

# --- Clean up after the demo ----------------------------------------------
# Remove the URL:
# aws lambda delete-function-url-config --function-name "$FN"
#
# The policy statements stay. Remove each one with its Sid from get-policy:
# aws lambda remove-permission --function-name "$FN" \
#   --statement-id <sid-from-get-policy>
