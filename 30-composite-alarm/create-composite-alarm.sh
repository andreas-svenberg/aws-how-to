#!/bin/bash
# create-composite-alarm.sh
# Create a composite alarm that goes to ALARM only when the site check
# alarm AND the CPU alarm are both in ALARM.
# Run in a terminal or CloudShell.
# Cost: composite alarms are billed per alarm and month. Delete after trying it.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- Settings (change them if yours are different) -----------------------
REGION=eu-north-1                    # the region of the alarms and the topic
TOPIC_NAME=${PREFIX}-alarms          # the SNS topic for the notification
SITE_ALARM=${PREFIX}-site-check      # first alarm in the rule
CPU_ALARM=${PREFIX}-cpu-high         # second alarm in the rule
COMPOSITE=${PREFIX}-site-and-cpu     # the name of the composite alarm

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
TOPIC=arn:aws:sns:$REGION:$ACCOUNT:$TOPIC_NAME

# Double quotes around the alarm names in the rule, so keep each part
# in its own variable to keep the command readable.
A="ALARM(\"$SITE_ALARM\")"
B="ALARM(\"$CPU_ALARM\")"
echo "Rule: $A AND $B"

# Create (or overwrite) the composite alarm. No output on success.
aws cloudwatch put-composite-alarm \
  --alarm-name "$COMPOSITE" \
  --alarm-rule "$A AND $B" \
  --alarm-actions "$TOPIC" \
  --region "$REGION"
