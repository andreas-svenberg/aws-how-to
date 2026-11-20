#!/bin/bash
# test-sms-alarm.sh
# Check the SMS subscription on the alarm topic and test it.
# Run in a terminal or CloudShell.
# Never commit a real phone number to a repository.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- Settings (change them if yours are different) -----------------------
REGION=eu-north-1               # the region of the topic and the alarm
TOPIC_NAME=${PREFIX}-alarms     # the SNS topic that the alarm sends to
ALARM_NAME=${PREFIX}-cpu-high   # the CloudWatch alarm to test with

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
TOPIC=arn:aws:sns:$REGION:$ACCOUNT:$TOPIC_NAME

# List the subscriptions on the topic (email and sms should both show)
aws sns list-subscriptions-by-topic \
  --topic-arn "$TOPIC" \
  --region "$REGION" \
  --query 'Subscriptions[].[Protocol,Endpoint]' \
  --output table

# Force the alarm to ALARM. It returns to its real state
# at the next evaluation.
aws cloudwatch set-alarm-state \
  --alarm-name "$ALARM_NAME" \
  --state-value ALARM \
  --state-reason "Test SMS" \
  --region "$REGION"
