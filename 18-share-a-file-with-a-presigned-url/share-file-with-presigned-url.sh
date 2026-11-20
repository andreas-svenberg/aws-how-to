#!/bin/bash
# share-file-with-presigned-url.sh
# Uploads a small test file to a private bucket and prints two addresses:
# the plain object URL (should give AccessDenied) and a presigned URL
# that works for a limited time.
#
# Run in CloudShell.
# Usage:
#   bash share-file-with-presigned-url.sh <bucket-name> [seconds]
#   seconds  optional, default 300 (5 minutes), max 604800 (7 days)
#
# Clean up afterwards:
#   aws s3 rm s3://<bucket-name>/hello.txt --region <region>
#   rm hello.txt

# --- Settings (change them if yours are different) -----------------------
REGION="eu-north-1"   # the region of the bucket
KEY="hello.txt"       # the name of the test file

BUCKET="$1"
EXPIRES="${2:-300}"

if [ -z "$BUCKET" ]; then
  echo "Usage: bash share-file-with-presigned-url.sh <bucket-name> [seconds]" >&2
  exit 1
fi

# Never share presigned links to a backup bucket (database dumps).
case "$BUCKET" in
  *backup*)
    echo "Refusing: do not share files from a backup bucket." >&2
    exit 1
    ;;
esac

echo "Hello, created $(date -u '+%Y-%m-%d %H:%M:%S') UTC" > "$KEY"

aws s3 cp "$KEY" "s3://${BUCKET}/${KEY}" --region "$REGION" || exit 1

echo
echo "1) Plain URL (should give AccessDenied, the bucket is private):"
echo "https://${BUCKET}.s3.${REGION}.amazonaws.com/${KEY}"
echo
echo "2) Presigned URL, valid for ${EXPIRES} seconds from now ($(date -u '+%H:%M:%S') UTC):"
aws s3 presign "s3://${BUCKET}/${KEY}" --expires-in "$EXPIRES" --region "$REGION"
