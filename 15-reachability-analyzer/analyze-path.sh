#!/usr/bin/env bash
# analyze-path.sh
# Reachability Analyzer from the CLI: is there a path from the internet
# gateway <prefix>-igw to the running instance <prefix>-web on TCP port 22?
# Run in a terminal in the folder that also contains port-filter.json.
# The destination port is set in port-filter.json (change 22 to 3306
# to test the database port). Each analysis is billed.

if [ -z "$PREFIX" ]; then
  echo "Set PREFIX first, for example PREFIX=demo"
  exit 1
fi

# --- Settings (change them if your resources have other Name tags) ----
IGW_NAME=${PREFIX}-igw
INSTANCE_NAME=${PREFIX}-web

# --- 1. Look up the ids --------------------------------------------------
IGW=$(aws ec2 describe-internet-gateways \
  --filters Name=tag:Name,Values=$IGW_NAME \
  --query 'InternetGateways[0].InternetGatewayId' --output text)
INSTANCE=$(aws ec2 describe-instances \
  --filters Name=tag:Name,Values=$INSTANCE_NAME \
            Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
echo "Source: $IGW  Destination: $INSTANCE"
if [ "$IGW" = "None" ] || [ "$INSTANCE" = "None" ]; then
  echo "Internet gateway or running instance not found."
  exit 1
fi

# --- 2. Create the path (source, destination, protocol, port) ----------
PATH_ID=$(aws ec2 create-network-insights-path \
  --source $IGW --destination $INSTANCE --protocol TCP \
  --filter-at-source file://port-filter.json \
  --query 'NetworkInsightsPath.NetworkInsightsPathId' --output text)
echo "Path: $PATH_ID"

# --- 3. Start the analysis ---------------------------------------------
ANALYSIS_ID=$(aws ec2 start-network-insights-analysis \
  --network-insights-path-id $PATH_ID \
  --query 'NetworkInsightsAnalysis.NetworkInsightsAnalysisId' --output text)
echo "Analysis: $ANALYSIS_ID (takes a few minutes)"

# --- 4. Wait for the result (one check every 20 seconds) ----------------
while true; do
  STATUS=$(aws ec2 describe-network-insights-analyses \
    --network-insights-analysis-ids $ANALYSIS_ID \
    --query 'NetworkInsightsAnalyses[0].Status' --output text)
  echo "Status: $STATUS"
  [ "$STATUS" != "running" ] && break
  sleep 20
done

# NetworkPathFound True = Reachable, False = Not reachable
aws ec2 describe-network-insights-analyses \
  --network-insights-analysis-ids $ANALYSIS_ID \
  --query 'NetworkInsightsAnalyses[0].[Status,NetworkPathFound]' \
  --output table

# For Not reachable, the explanations say which component blocks:
aws ec2 describe-network-insights-analyses \
  --network-insights-analysis-ids $ANALYSIS_ID \
  --query 'NetworkInsightsAnalyses[0].Explanations[].ExplanationCode' \
  --output text

# --- Clean up afterwards (run these lines by hand) ----------------------
#   aws ec2 delete-network-insights-analysis \
#     --network-insights-analysis-id nia-...
#   aws ec2 delete-network-insights-path \
#     --network-insights-path-id nip-...
