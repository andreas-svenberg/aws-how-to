#!/usr/bin/env bash
# schedule.sh
# Scheduled actions for an Auto Scaling group:
#   <prefix>-night    every day 20:00          -> min 1, max 1, desired 1
#   <prefix>-morning  Monday-Friday 07:00      -> min 2, max 4, desired 2
# Running the script again overwrites actions with the same name.
# Run in a terminal on your own computer, or in CloudShell.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example PREFIX=demo"
  exit 1
fi

# Change these to match your group and your time zone.
ASG="${PREFIX}-web-asg"
TIME_ZONE="Europe/Stockholm"

# --- 1. Evening: scale in to one server ---------------------------------
# Cron: minute hour day-of-month month day-of-week, always in quotes.
# Without --time-zone the cron expression is read as UTC.
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name "$ASG" \
  --scheduled-action-name "${PREFIX}-night" \
  --recurrence "0 20 * * *" \
  --time-zone "$TIME_ZONE" \
  --min-size 1 --max-size 1 --desired-capacity 1

# --- 2. Weekday morning: back to the normal size ------------------------
# Change the sizes to your group's normal min, max and desired.
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name "$ASG" \
  --scheduled-action-name "${PREFIX}-morning" \
  --recurrence "0 7 * * 1-5" \
  --time-zone "$TIME_ZONE" \
  --min-size 2 --max-size 4 --desired-capacity 2

# --- 3. Show the actions -------------------------------------------------
aws autoscaling describe-scheduled-actions \
  --auto-scaling-group-name "$ASG" --output table

# --- Clean up (run by hand when you are done) ---------------------------
# aws autoscaling delete-scheduled-action \
#   --auto-scaling-group-name "${PREFIX}-web-asg" \
#   --scheduled-action-name "${PREFIX}-night"
# aws autoscaling delete-scheduled-action \
#   --auto-scaling-group-name "${PREFIX}-web-asg" \
#   --scheduled-action-name "${PREFIX}-morning"
