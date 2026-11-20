#!/bin/bash
# Generates the IAM credential report and saves it as a CSV file.
# Run in CloudShell: bash save-credential-report.sh
aws iam generate-credential-report > /dev/null
sleep 5
# The report content comes base64 encoded
aws iam get-credential-report --query Content --output text | base64 -d > credential-report.csv
# user, password_enabled, password_last_used, mfa_active, access_key_1_active
cut -d, -f1,4,5,8,9 credential-report.csv
