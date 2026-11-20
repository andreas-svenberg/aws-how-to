#!/usr/bin/env bash
# connect-with-endpoint.sh
# EC2 Instance Connect Endpoint: SSH to a server in a private subnet
# without a bastion and without a public IP.
# Run section by section in a terminal (copy and paste), not as one script:
# the endpoint itself is created in the console between section 2 and 3.
# Requires AWS CLI v2. Set PREFIX before you paste, for example PREFIX=demo

# Git Bash would otherwise turn the /aws/service/... SSM path into a Windows path.
export MSYS_NO_PATHCONV=1

# Warns without closing the terminal (this file is pasted, not run)
[ -z "$PREFIX" ] && echo "WARNING: PREFIX is not set. Set it, for example PREFIX=demo, and paste again."

# --- Settings (change them if your resources have other Name tags) ----
VPC_NAME=${PREFIX}-vpc
SUBNET_NAME=${PREFIX}-private-a
EICE_SG_NAME=${PREFIX}-eice-sg
PRIV_SG_NAME=${PREFIX}-private-sg
INSTANCE_NAME=${PREFIX}-private-test
echo "VPC: $VPC_NAME  Subnet: $SUBNET_NAME  (if these start with a dash, PREFIX is not set)"

# === Section 1: security groups ========================================
VPC=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=$VPC_NAME \
  --query 'Vpcs[0].VpcId' --output text)
SUBNET=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=$SUBNET_NAME \
  --query 'Subnets[0].SubnetId' --output text)
echo "VPC: $VPC  Subnet: $SUBNET"

# Group for the endpoint
EICE_SG=$(aws ec2 create-security-group --group-name $EICE_SG_NAME \
  --description "EC2 Instance Connect Endpoint" --vpc-id $VPC \
  --query 'GroupId' --output text)
# Group for the test instance
PRIV_SG=$(aws ec2 create-security-group --group-name $PRIV_SG_NAME \
  --description "Private test instance, SSH from the endpoint" --vpc-id $VPC \
  --query 'GroupId' --output text)
echo "Endpoint SG: $EICE_SG  Instance SG: $PRIV_SG"

# Endpoint group: no inbound rules. Outbound: replace "all traffic"
# with TCP 22 to the instance group only.
aws ec2 revoke-security-group-egress --group-id $EICE_SG \
  --ip-permissions 'IpProtocol=-1,IpRanges=[{CidrIp=0.0.0.0/0}]'
aws ec2 authorize-security-group-egress --group-id $EICE_SG \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,UserIdGroupPairs=[{GroupId=$PRIV_SG}]"

# Instance group: inbound 22 only from the endpoint group.
aws ec2 authorize-security-group-ingress --group-id $PRIV_SG \
  --protocol tcp --port 22 --source-group $EICE_SG

# === Section 2: test instance (no public IP, no key pair) ==============
ID=$(aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro --subnet-id $SUBNET \
  --security-group-ids $PRIV_SG --no-associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query 'Instances[0].InstanceId' --output text)
echo "Instance: $ID"
aws ec2 wait instance-running --instance-ids $ID
echo "Instance is running. Now create the endpoint in the console."

# === Section 3: connect (when the endpoint is Available) ================
aws ec2-instance-connect ssh --instance-id $ID \
  --os-user ec2-user --connection-type eice

# On the instance:
#   hostname
#   curl -m 5 https://checkip.amazonaws.com   # no answer: no route out
#   exit

# === Clean up (in this order) ==========================================
# 1. Terminate the test instance and wait:
#   aws ec2 terminate-instances --instance-ids $ID
#   aws ec2 wait instance-terminated --instance-ids $ID
# 2. Delete the endpoint (id starts with eice-):
#   aws ec2 describe-instance-connect-endpoints \
#     --query 'InstanceConnectEndpoints[].[InstanceConnectEndpointId,State]' --output table
#   aws ec2 delete-instance-connect-endpoint --instance-connect-endpoint-id eice-...
# 3. The two groups refer to each other, remove one rule first:
#   aws ec2 revoke-security-group-ingress --group-id $PRIV_SG \
#     --protocol tcp --port 22 --source-group $EICE_SG
#   aws ec2 delete-security-group --group-id $EICE_SG
#   aws ec2 delete-security-group --group-id $PRIV_SG
