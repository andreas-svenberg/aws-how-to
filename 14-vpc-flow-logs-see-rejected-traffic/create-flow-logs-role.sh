#!/usr/bin/env bash
# create-flow-logs-role.sh
# Creates the IAM role that VPC Flow Logs uses to write to CloudWatch Logs,
# and the log group the flow log will write to.
# Run in a terminal in the folder that also contains:
#   flow-logs-trust-policy.json
#   flow-logs-permissions.json
# The flow log itself is created in the console.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example PREFIX=demo"
  exit 1
fi

# Git Bash on Windows would otherwise turn /<prefix>/... into a Windows path.
export MSYS_NO_PATHCONV=1

# --- Settings ---------------------------------------------------------
ROLE_NAME=${PREFIX}-flowlogs-role
POLICY_NAME=${PREFIX}-flowlogs-write
LOG_GROUP=/${PREFIX}/vpc/flowlogs

# --- 1. Role that the VPC Flow Logs service may assume -----------------
aws iam create-role --role-name $ROLE_NAME \
  --assume-role-policy-document file://flow-logs-trust-policy.json \
  --query 'Role.Arn' --output text

# --- 2. Inline policy: write to CloudWatch Logs ------------------------
aws iam put-role-policy --role-name $ROLE_NAME \
  --policy-name $POLICY_NAME \
  --policy-document file://flow-logs-permissions.json

# --- 3. Log group, keep data for one day only ---------------------------
aws logs create-log-group --log-group-name $LOG_GROUP
aws logs put-retention-policy --log-group-name $LOG_GROUP \
  --retention-in-days 1

echo "Role $ROLE_NAME and log group $LOG_GROUP created."

# --- Clean up afterwards (run these lines by hand) ----------------------
# 1. Find and delete the flow log:
#   aws ec2 describe-flow-logs \
#     --query 'FlowLogs[].[FlowLogId,LogGroupName]' --output table
#   aws ec2 delete-flow-logs --flow-log-ids fl-...
# 2. Delete the log group (in Git Bash, MSYS_NO_PATHCONV=1 is still needed):
#   MSYS_NO_PATHCONV=1 aws logs delete-log-group \
#     --log-group-name /${PREFIX}/vpc/flowlogs
# 3. Delete the role (inline policy first):
#   aws iam delete-role-policy --role-name ${PREFIX}-flowlogs-role \
#     --policy-name ${PREFIX}-flowlogs-write
#   aws iam delete-role --role-name ${PREFIX}-flowlogs-role
