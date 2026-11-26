#!/bin/bash
# test-composite-alarm.sh
# Force both alarms to ALARM and watch the composite alarm.
# The single alarms still send their own notifications. Both return to their
# real state at the next evaluation, after seconds to a minute, and the
# composite alarm follows at once. So the state is read directly, and the
# history at the end shows the whole sequence.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- Settings (change them if yours are different) -----------------------
REGION=eu-north-1                    # the region of the alarms
SITE_ALARM=${PREFIX}-site-check      # first alarm in the rule
CPU_ALARM=${PREFIX}-cpu-high         # second alarm in the rule
COMPOSITE=${PREFIX}-site-and-cpu     # the composite alarm to watch

STATE() {
  aws cloudwatch describe-alarms \
    --alarm-names "$COMPOSITE" \
    --alarm-types CompositeAlarm \
    --query 'CompositeAlarms[0].StateValue' \
    --output text \
    --region "$REGION"
}

# Step 1: only one condition is true, composite should not change
aws cloudwatch set-alarm-state \
  --alarm-name "$CPU_ALARM" \
  --state-value ALARM \
  --state-reason "Test composite" \
  --region "$REGION"
echo "Composite after $CPU_ALARM: $(STATE)"

# Step 2: both conditions true, composite should go to ALARM
aws cloudwatch set-alarm-state \
  --alarm-name "$SITE_ALARM" \
  --state-value ALARM \
  --state-reason "Test composite" \
  --region "$REGION"
echo "Composite after $SITE_ALARM: $(STATE)"

# The composite alarm's history. Without --alarm-types CompositeAlarm it is empty.
aws cloudwatch describe-alarm-history \
  --alarm-name "$COMPOSITE" \
  --alarm-types CompositeAlarm \
  --history-item-type StateUpdate \
  --max-items 4 \
  --query 'AlarmHistoryItems[].[Timestamp,HistorySummary]' \
  --output table \
  --region "$REGION"

# --- Clean up afterwards (run by hand) -----------------------------------
# One composite alarm per delete-alarms call. With two names the call fails
# with a ValidationError and nothing is deleted.
# aws cloudwatch delete-alarms --alarm-names <prefix>-site-and-cpu
# aws cloudwatch delete-alarms --alarm-names <prefix>-cpu-and-unhealthy
