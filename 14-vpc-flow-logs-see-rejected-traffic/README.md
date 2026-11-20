# 14 VPC Flow Logs, see rejected traffic

## What it is

Security groups and network ACLs stop traffic silently, and all you notice is that something does not answer. A flow log records the traffic in a VPC, so that you can see what was actually stopped, where it came from and which port it was aimed at. You create a role and a log group, turn on a flow log for a VPC that only keeps rejected traffic, provoke a rejected connection and search for it with CloudWatch Logs Insights.

## Why and when to use it

- **When a security group or a network ACL denies a packet, no answer is sent.** Whoever tries to connect only sees a timeout, and nothing shows in the console.
- **A flow log records information about the traffic** to and from the network interfaces in the VPC. Not the content of the traffic, only information about each connection.
- **For each row you see** the source address and port, the destination address and port, the protocol, how much data was sent, and whether the traffic was accepted or rejected.
- **When you turn it on, you soon notice that the internet knocks on your public addresses all the time.** Unknown addresses try different ports day and night, and it is good to have seen it with your own eyes.
- **In operations, flow logs are evidence** both when something does not work and when someone asks what has tried to reach the servers.

## How it works

- **A flow log can be turned on for a whole VPC, a subnet or a single network interface.** This guide uses the whole VPC, so that all servers and subnets are included.
- **The filter decides what is kept:** `Accept` keeps traffic that was let in, `Reject` traffic that was denied, and `All` both. This guide uses `Reject`, since that is the traffic to look at, and it gives less data.
- **The log can be sent to CloudWatch Logs.** Then it is the VPC Flow Logs service that writes to a log group for you, and it needs permissions in the form of an IAM role. The role's trust policy says that the service `vpc-flow-logs.amazonaws.com` may assume the role. The permissions are to create log groups and log streams, write log events and list them.
- **The log can also be sent to an S3 bucket,** and then no role is needed. This guide uses CloudWatch Logs, to be able to search the log directly in the console.
- **The log does not come at once.** Delivery to CloudWatch Logs takes about five minutes, and AWS promises nothing exact. Expect five to ten minutes before the rows show.

## Prerequisites

- A VPC with a server that has a public IP address, and a port that is not open in its security group, for example 3306. See [Create a flow log that publishes to CloudWatch Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-cwl-create-flow-log.html).
- A user that may create IAM roles, for example an administrator.
- The AWS CLI on your computer, signed in. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- For the test in step 3: PowerShell on Windows.
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

| Placeholder | What it is | Example |
|---|---|---|
| `<vpc-name>` | The VPC to log (VPC, Your VPCs) | `demo-vpc` |
| `<public-ip>` | The server's public IPv4 address (EC2, Instances, the instance) | `203.0.113.10` |

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Create the role and the log group

1. Put [create-flow-logs-role.sh](create-flow-logs-role.sh), [flow-logs-trust-policy.json](flow-logs-trust-policy.json) and [flow-logs-permissions.json](flow-logs-permissions.json) in the same folder. The script uses `file://` followed by the file name, so it must be run where the files are.
2. Open a terminal in that folder and run the script:

   ```
   bash create-flow-logs-role.sh
   ```

   - At the top, the script sets `MSYS_NO_PATHCONV=1`, since the log group's name starts with a slash and Git Bash on Windows would otherwise turn it into a Windows path.
   - First, `aws iam create-role` creates the role `<prefix>-flowlogs-role` with the trust policy from the file. The script prints the role's ARN, the one starting with `arn:aws:iam`.
   - Then `aws iam put-role-policy` puts the permissions directly in the role as an inline policy called `<prefix>-flowlogs-write`.
   - Last, `aws logs create-log-group` creates the log group `/<prefix>/vpc/flowlogs`. The script also sets the retention to one day with `put-retention-policy`, so that the log does not grow unnecessarily.

### 2. Create the flow log in the console

1. Go to VPC and choose **Your VPCs** in the menu on the left.
2. Select `<vpc-name>`, choose **Actions** and then **Create flow log**. Make sure it is the right VPC, otherwise the log ends up on a VPC where there are no servers.
3. Choose **Reject** in the field **Filter**. Set **Maximum aggregation interval** to **1 minute**. It means that the traffic is collected in periods of at most one minute, so that the rows come as often as possible.
4. Choose **Send to CloudWatch Logs** as **Destination**. Choose `/<prefix>/vpc/flowlogs` as **Destination log group**. In the field **Service access**, choose the existing role `<prefix>-flowlogs-role`. Without the role, the service cannot write anything.
5. Leave **Log record format** as **AWS default format**, the standard format with fourteen fields. Create the flow log at the bottom of the page, and check that it shows on the VPC.

### 3. Provoke a rejected connection and search for it

1. Open PowerShell on your own computer and try to reach a port that is closed. `Test-NetConnection` is a PowerShell command, so it does not work in Git Bash.

   ```
   Test-NetConnection <public-ip> -Port 3306
   ```

   The answer is that `TcpTestSucceeded` is `False`, the connection did not get through.

2. Wait five to ten minutes.
3. Go to CloudWatch. In the menu on the left, under **Logs**, there is **Log Analytics**. The queries are still written and run with Logs Insights. Choose the log group `/<prefix>/vpc/flowlogs`. Set the time range to the last half hour, so that your test is surely included.
4. Paste the query from [rejected-traffic-query.txt](rejected-traffic-query.txt) and run it. It picks out the fields for time, source, destination, destination port and action, filters on `REJECT`, sorts with the latest first and shows twenty rows.

   ```
   fields @timestamp, srcAddr, dstAddr, dstPort, action
   | filter action = 'REJECT'
   | sort @timestamp desc
   | limit 20
   ```

   If the field names come back empty, the file also has a fallback query that parses the raw line.

## Check the result

- **`filter action = 'REJECT'`** shows only denied traffic. The flow log already keeps only `Reject`, but the filter does no harm and makes the query useful also for a log with `All`.
- **Find a row where `srcAddr` is your own public address and `dstPort` is 3306.** That is your test from PowerShell. There may also be a row with port 0 from your address, since `Test-NetConnection` also tries ping when the port does not answer.
- **You will also see rows from addresses you do not recognise,** against ports that were never opened. That is the internet knocking, and it goes on all the time against all public addresses. Your rules stop it, and now you see that they do.
- **`srcAddr`** is the source address, who tried. **`dstAddr`** is the destination, and inside the VPC it is the server's private address, not the public one. **`dstPort`** is the port they tried to reach.
- **In the default format there are fourteen fields** in this order: version, account id, network interface id, source address, destination address, source port, destination port, protocol, packets, bytes, start, end, action and log status. Action is field number thirteen and is either `ACCEPT` or `REJECT`.
- **`REJECT` means that a security group or a network ACL stopped the packet.** The log does not say which of them. For that, look at the rules, or use Reachability Analyzer, see guide 15.

## Clean up

A flow log costs money while it writes. Remove the flow log, the log group and the role when you are done. The commands are also at the end of `create-flow-logs-role.sh`.

1. Find the flow log's id and delete it:

   ```
   aws ec2 describe-flow-logs --query 'FlowLogs[].[FlowLogId,LogGroupName]' --output table
   ```

   ```
   aws ec2 delete-flow-logs --flow-log-ids <flow-log-id>
   ```

2. Delete the log group. In Git Bash, `MSYS_NO_PATHCONV=1` is still needed:

   ```
   MSYS_NO_PATHCONV=1 aws logs delete-log-group --log-group-name /${PREFIX}/vpc/flowlogs
   ```

3. Delete the role, the inline policy first:

   ```
   aws iam delete-role-policy --role-name ${PREFIX}-flowlogs-role --policy-name ${PREFIX}-flowlogs-write
   ```

   ```
   aws iam delete-role --role-name ${PREFIX}-flowlogs-role
   ```

## Good to know

- **Cost:** flow logs to CloudWatch Logs are billed as vended logs, per GB. See [Amazon CloudWatch Pricing](https://aws.amazon.com/cloudwatch/pricing/) for the current price in your region. With the filter `Reject` and a single server, it is small amounts.

## Common errors

| Symptom | Cause |
|---|---|
| No rows directly | Delivery takes about five minutes and sometimes more. Wait and search again before you start troubleshooting. |
| No rows at all after a quarter of an hour | The role was not chosen in **Service access**, or the wrong role was chosen. Then the service cannot write in the log group. Check the role and its trust policy. |
| A log group with a name starting with `C:/Program Files` | In Git Bash on Windows, `MSYS_NO_PATHCONV=1` was missing in a command where the log group's name starts with a slash. |
| `Test-NetConnection` is not found | It was run in Git Bash. It is a PowerShell command. |

## Files

| File | What it is |
|---|---|
| `create-flow-logs-role.sh` | Creates the role and the log group. The clean-up commands are at the end. |
| `flow-logs-trust-policy.json` | The role's trust policy: the VPC Flow Logs service may assume the role. |
| `flow-logs-permissions.json` | The role's permissions: write to CloudWatch Logs. |
| `rejected-traffic-query.txt` | The Logs Insights query for rejected traffic, with a fallback that parses the raw line. |
