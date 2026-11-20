#!/bin/bash
# open-database-tunnel.sh
# Opens an SSH tunnel from this computer to the private RDS database
# <prefix>-db, through the web server <prefix>-web. Run in a terminal
# and leave the window open.
#
# Usage:
#   bash open-database-tunnel.sh [rds-endpoint] [local-port]
#   rds-endpoint  optional, fetched with the AWS CLI if left out
#   local-port    optional, default 3306 (use 3307 if a local MariaDB/MySQL uses 3306)
#
# Then connect your database tool (MariaDB or MySQL over TCP/IP) to:
#   host 127.0.0.1, port <local-port>, the database user and password
#
# The tunnel uses the host <prefix>-web from ~/.ssh/config.
# Without a bastion host, an entry like this is enough:
#
#   Host <prefix>-web
#       HostName <public-ip-of-the-web-server>
#       User ec2-user
#       IdentityFile ~/.ssh/<key>.pem
#
# With a bastion host, the entry has the private IP of the web server and
#       ProxyJump <prefix>-bastion
# and the tunnel goes through the bastion automatically. Keep the tunnel ending
# at the web server: the database's security group only allows port 3306
# from the web server's security group.
#
# The same tunnel as a single command:
#   ssh -N -L 3306:<rds-endpoint>:3306 <prefix>-web

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example export PREFIX=demo"
  exit 1
fi

# --- Settings (change them if your resources have other names) --------
DB_NAME=${PREFIX}-db        # the DB identifier of the database in RDS
SSH_HOST=${PREFIX}-web      # the host name of the web server in ~/.ssh/config
REGION=eu-north-1           # the region of the database, change it if yours is different

ENDPOINT="$1"
LOCAL_PORT="${2:-3306}"

if [ -z "$ENDPOINT" ]; then
  echo "No endpoint given, asking RDS for the address of ${DB_NAME}..."
  ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_NAME" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text --region "$REGION")
fi

if [ -z "$ENDPOINT" ] || [ "$ENDPOINT" = "None" ]; then
  echo "Could not find the endpoint for ${DB_NAME}." >&2
  exit 1
fi

echo "Tunnel: 127.0.0.1:${LOCAL_PORT} to ${ENDPOINT}:3306 via ${SSH_HOST}"
echo "Connect your database tool to 127.0.0.1 port ${LOCAL_PORT}."
echo "The window will stay quiet. Press Ctrl+C to close the tunnel."

ssh -N -L "${LOCAL_PORT}:${ENDPOINT}:3306" "$SSH_HOST"
