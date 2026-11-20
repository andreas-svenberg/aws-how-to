# 15 Reachability Analyzer

## What it is

The question everyone asks sooner or later: why can I not reach the server? Many places can stop the traffic: security groups, network ACLs and route tables. Reachability Analyzer goes through them for you and points out what blocks. You analyse the path from an internet gateway to a server, first on port 22, which should work, and then on port 3306, which should not, and read the explanation. Then you do the same with the AWS CLI.

## Why and when to use it

- **Traffic from the internet to a server passes** the internet gateway, the subnet's route table, the network ACL and the security group. The error can be in any of those places.
- **Going through everything by hand takes time,** and it is easy to look at the wrong rule, the wrong direction or the wrong subnet.
- **Reachability Analyzer sends no packets.** It reads how the network is configured and works out whether there is a path between the source and the destination.
- **The answer is simple:** Reachable if there is a path, Not reachable if there is none. It is shown as **Reachability status** in the result.
- **For Not reachable, it also explains why.** Under **Explanations** it says which component stops the traffic, for example a security group or a network ACL.

## How it works

- **You start by describing a path.** A path has a source, a destination, a protocol and a port. The path is saved, and then you can run an analysis on it.
- **Source and destination** can be several kinds of resources, among them EC2 instances, internet gateways and network interfaces. In this guide, the source is the internet gateway, where the traffic from the internet comes in, and the destination is the server.
- **The destination can also be given as an IP address.** That is useful to check a certain address, for example a private address in another subnet.
- **The protocol is TCP or UDP.** SSH and web are TCP. The port is given as the destination port, the port on the server that the traffic should reach.
- **It only works for IPv4,** and the source and destination must be in the same region.
- **Every analysis is billed.** See [Amazon VPC Pricing](https://aws.amazon.com/vpc/pricing/) for the current price. Do not run analyses in a loop. Two or three are enough for this guide.

## Prerequisites

- A VPC with an internet gateway, named for example `<prefix>-igw`, and a running server in a public subnet, named for example `<prefix>-web`, with a security group that allows SSH (port 22) from your address. See [What is Reachability Analyzer?](https://docs.aws.amazon.com/vpc/latest/reachability/what-is-reachability-analyzer.html).
- For the CLI part: the AWS CLI on your computer, signed in. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your internet gateway or server has another name, use that name instead in the console and in `analyze-path.sh`.

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for step 3. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. From the internet to SSH

1. Type **Network Manager** in the search field at the top of the console and open the service. Check that the region is the one where your resources are, since the analysis only sees resources in the same region.
2. Choose **Reachability Analyzer** and then **Create and analyze path**. Give the path a name, for example `<prefix>-igw-to-web-22`, so that you find it again.
3. Choose **Internet gateway** as source type and `<prefix>-igw` as source. Choose **Instance** as destination type and `<prefix>-web` as destination. If you have several instances, look at the Name tag.
4. Choose **TCP** as protocol and type `22` as destination port. Leave the other fields empty, they are not needed for this question.
5. Start the analysis. It takes a few minutes, and meanwhile it shows as pending.

The result should be **Reachable**. That means that the route table, the network ACL's rule for SSH and the security group's rule for port 22 together let the traffic through.

If you reach your servers through a bastion host, the server's security group only lets in SSH from the bastion. Then the answer is **Not reachable** here, and that is right. Change the destination to the bastion instead.

### 2. The same path with port 3306

1. Create a new path in Reachability Analyzer with the same source and destination. Give it a name ending in `3306`.
2. Choose **TCP** and type `3306` as destination port. That is the port MySQL and MariaDB use.
3. Start the analysis and wait a few minutes, as before. Then read **Reachability status**.

Now the answer is **Not reachable**. That is exactly what you want, since nobody should be able to reach a database port from the internet. Here, Not reachable is proof that the network is built right.

4. Read the section **Explanations** in the result. It says what blocks the traffic and which component it is, with the component's name or id. It points out the security group, which has no rule for 3306, or the network ACL, which does not let in 3306 either. Both are right. It is the same rejected traffic that a flow log shows as `REJECT`, see [guide 14](../14-vpc-flow-logs-see-rejected-traffic/).

### 3. The same analysis with the AWS CLI

1. Put [port-filter.json](port-filter.json) in the same folder as [analyze-path.sh](analyze-path.sh). The file gives the destination port, `DestinationPortRange` with `FromPort` and `ToPort` 22. Change it to 3306 in both places to test the database port.
2. Open a terminal in the folder. The script looks up the ids of `<prefix>-igw` and the running `<prefix>-web` itself, with the Name tag.

   ```
   bash analyze-path.sh
   ```

   The script prints the ids of the source, destination, path and analysis, and then the status every twenty seconds until the analysis is done.

What the script does:

- The path is created with `aws ec2 create-network-insights-path`, with `--source` for the gateway, `--destination` for the instance, `--protocol TCP` and `--filter-at-source` with the file. The answer is an id starting with `nip`.
- The analysis is started with `aws ec2 start-network-insights-analysis` and the path's id. This is the line that is billed.
- The result is read with `aws ec2 describe-network-insights-analyses`. `NetworkPathFound` `True` corresponds to Reachable and `False` to Not reachable. For `False`, the script also prints the codes from Explanations.

## Check the result

- Port 22 from the internet gateway to the server: **Reachable** (or Not reachable with a bastion design, pointing at the security group).
- Port 3306: **Not reachable**, with Explanations pointing at the security group or the network ACL.
- In the CLI: `NetworkPathFound` `True` or `False`.

## Clean up

Remove the paths and analyses in Reachability Analyzer when you are done, so that the list does not fill up. In the console: select the path and delete it. With the CLI, the commands are also at the end of the script:

```
aws ec2 delete-network-insights-analysis --network-insights-analysis-id <nia-id>
```

```
aws ec2 delete-network-insights-path --network-insights-path-id <nip-id>
```

## Reachability Analyzer compared with flow logs

| Reachability Analyzer | Flow logs ([guide 14](../14-vpc-flow-logs-see-rejected-traffic/)) |
|---|---|
| Reads the configuration and answers whether traffic would get through. No traffic needs to have been sent. | Shows traffic that has actually reached the network interfaces, and whether it was accepted or rejected. Only what has already happened. |
| Answers after a few minutes, and only for the path you asked about. You must know what you are looking for. | Collects everything continuously, also things you did not know you were looking for. But the rows come five to ten minutes after the traffic. |
| Billed per analysis, and only when you run one. | Billed per GB of log data, for as long as the log is on. |

## Good to know

- **Reachable does not mean that the service answers.** It means that the network lets the traffic through. If the web server is turned off, the path can still be Reachable. Then the error is on the server, not in the network.
- **Not reachable is not always an error.** For port 3306 from the internet, it is exactly what you want.
- **Change one thing at a time and then analyse,** instead of clicking analyse again and again while troubleshooting.

## Common errors

| Symptom | Cause |
|---|---|
| The internet gateway or the server is not in the lists | The console is in another region. The analysis only sees resources in the same region. |
| Port 22 is Not reachable although SSH should work | With a bastion design, that is right: the server only lets in SSH from the bastion. Otherwise, read Explanations to see which component blocks. |
| The script says *Internet gateway or running instance not found* | The Name tags are not `<prefix>-igw` and `<prefix>-web`, or the server is not running. Change the settings at the top of the script. |

## Files

| File | What it is |
|---|---|
| `analyze-path.sh` | Creates a path from the internet gateway to the server, runs an analysis and shows the result. The clean-up commands are at the end. |
| `port-filter.json` | The destination port for the path. Change 22 to 3306 to test the database port. |
