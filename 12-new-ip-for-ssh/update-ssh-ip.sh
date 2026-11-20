#!/usr/bin/env bash
# update-ssh-ip.sh
# Point the SSH rules at your current public IP after it has changed.
# Updates two places: the inbound SSH rule in the security group
# and the inbound SSH rule in the public subnet's network ACL.
# Run in a terminal on your OWN computer, not in CloudShell
# (CloudShell would report CloudShell's address, not yours).

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- Settings (change them to match your setup) ------------------------
SG_NAME=${PREFIX}-web-sg          # with a bastion host: the bastion's security group
NACL_NAME=${PREFIX}-public-nacl
NACL_RULE=120                     # the number of your inbound SSH rule in the network ACL, change it if yours is different

# --- 1. Your current public IP -----------------------------------------
MYIP=$(curl -s https://checkip.amazonaws.com)
if [ -z "$MYIP" ]; then
  echo "Could not read your public IP. Check your network and try again."
  exit 1
fi
echo "Your public IP: $MYIP"

# --- 2. Security group: find the group and its port 22 rule ------------
SG=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=$SG_NAME \
  --query 'SecurityGroups[0].GroupId' --output text)
if [ -z "$SG" ] || [ "$SG" = "None" ]; then
  echo "Security group $SG_NAME not found."
  exit 1
fi
echo "Security group: $SG"

# Single quotes around the query because of the backticks.
RULE=$(aws ec2 describe-security-group-rules \
  --filters Name=group-id,Values=$SG \
  --query 'SecurityGroupRules[?FromPort==`22`].SecurityGroupRuleId' \
  --output text)
if [ -z "$RULE" ] || [ "$(echo $RULE | wc -w)" -ne 1 ]; then
  echo "Expected exactly one port 22 rule in $SG_NAME, found: '$RULE'"
  exit 1
fi
echo "SSH rule: $RULE"

# --- 3. Replace the security group rule (the whole rule is replaced) ---
aws ec2 modify-security-group-rules --group-id $SG \
  --security-group-rules "SecurityGroupRuleId=$RULE,SecurityGroupRule={IpProtocol=tcp,FromPort=22,ToPort=22,CidrIpv4=$MYIP/32}"

# --- 4. Network ACL: replace the inbound SSH rule ----------------------
NACL=$(aws ec2 describe-network-acls \
  --filters Name=tag:Name,Values=$NACL_NAME \
  --query 'NetworkAcls[0].NetworkAclId' --output text)
if [ -z "$NACL" ] || [ "$NACL" = "None" ]; then
  echo "Network ACL $NACL_NAME not found."
  exit 1
fi
echo "Network ACL: $NACL"

aws ec2 replace-network-acl-entry --network-acl-id $NACL \
  --ingress --rule-number $NACL_RULE --protocol 6 \
  --port-range From=22,To=22 --cidr-block $MYIP/32 --rule-action allow

# --- 5. Verify ---------------------------------------------------------
aws ec2 describe-security-group-rules \
  --filters Name=group-id,Values=$SG --output table

echo "Done. Now try ssh again."
