#!/bin/bash
# Shows the role's temporary credentials without printing the secret parts.
# Run on the server: bash show-role-credentials.sh
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
M=http://169.254.169.254/latest/meta-data
ROLE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "$M/iam/security-credentials/")
echo "Role: $ROLE"
# SecretAccessKey and Token are filtered out on purpose
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "$M/iam/security-credentials/$ROLE" \
  | grep -E '"(Code|LastUpdated|AccessKeyId|Expiration)"'
