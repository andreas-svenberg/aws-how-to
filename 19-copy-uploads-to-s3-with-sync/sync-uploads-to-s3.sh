#!/bin/bash
# sync-uploads-to-s3.sh
# Copies the WordPress uploads folder (on EFS) to a backup bucket,
# under the prefix uploads/. Only new or changed files are copied.
#
# Run on the web server. The server's role needs the inline policy
# in uploads-policy.json.
#
# Usage:
#   bash sync-uploads-to-s3.sh <bucket-name> --dryrun   (show what would be copied)
#   bash sync-uploads-to-s3.sh <bucket-name>            (copy for real)
#
# If some files cannot be read (permission denied), run it with sudo.

# --- Settings (change them if yours are different) -----------------------
SRC="/var/www/html/wp-content/uploads"   # the folder to copy
REGION="eu-north-1"                       # the region of the bucket

BUCKET="$1"
shift

if [ -z "$BUCKET" ]; then
  echo "Usage: bash sync-uploads-to-s3.sh <bucket-name> [--dryrun]" >&2
  exit 1
fi

DST="s3://${BUCKET}/uploads/"

# --delete would remove copies in S3 when files are deleted locally.
# That defeats the purpose of a backup, so this script refuses it.
for arg in "$@"; do
  if [ "$arg" = "--delete" ]; then
    echo "Refusing --delete: this is a backup copy." >&2
    exit 1
  fi
done

if [ ! -d "$SRC" ]; then
  echo "$SRC not found. Is EFS mounted on /var/www/html/wp-content?" >&2
  exit 1
fi

echo "Source: $SRC"
echo "Target: $DST"
echo "Extra options: $*"
echo

aws s3 sync "$SRC" "$DST" --region "$REGION" "$@"
