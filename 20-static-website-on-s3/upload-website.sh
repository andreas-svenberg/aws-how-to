#!/bin/bash
# upload-website.sh
# Uploads index.html to the website bucket and tests the website
# address with curl.
#
# Run in CloudShell (or a terminal with the AWS CLI), in the same folder
# as index.html. Static website hosting, Block public access and
# the bucket policy (public-read-policy.json) must already be set.
#
# Usage:
#   bash upload-website.sh <bucket-name>
#
# Clean up afterwards (empties and deletes the bucket in one step):
#   aws s3 rb s3://<bucket-name> --force --region <region>

# --- Settings (change them if yours are different) -----------------------
REGION="eu-north-1"   # the region of the bucket

BUCKET="$1"

if [ -z "$BUCKET" ]; then
  echo "Usage: bash upload-website.sh <bucket-name>" >&2
  exit 1
fi

PAGE="$(dirname "$0")/index.html"

if [ ! -f "$PAGE" ]; then
  echo "$PAGE not found. Upload it to the same folder as this script." >&2
  exit 1
fi

aws s3 cp "$PAGE" "s3://${BUCKET}/index.html" \
  --content-type "text/html; charset=utf-8" \
  --region "$REGION" || exit 1

URL="http://${BUCKET}.s3-website.${REGION}.amazonaws.com"

echo
echo "Website address (HTTP only):"
echo "$URL"
echo
# 200 = OK, 403 = no read access (policy or Block public access), 404 = no index.html
curl -s -o /dev/null -w "HTTP status: %{http_code}\n" "$URL/"
