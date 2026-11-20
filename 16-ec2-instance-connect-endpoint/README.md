# 16 EC2 Instance Connect Endpoint

## What it is

A server in a private subnet has no public IP address, so you cannot connect to it with SSH directly from your computer. A bastion host is one way to reach it. EC2 Instance Connect Endpoint is another: a service that AWS places in a subnet in your VPC, and that you connect through with the AWS CLI. You start a test server without a public IP in a private subnet, create an endpoint with its own security groups, connect with the AWS CLI and show that the server cannot reach the internet. Then you remove everything.

## Why and when to use it

- **A server in a private subnet has no public address and no route to the internet gateway.** That is the point, but it also means that you cannot run `ssh` against it directly from your computer.
- **A bastion host is one way to solve it.** You log in to a server in a public subnet and jump on from there, with ProxyJump in the SSH config, see [guide 13](../13-ssh-tunnel-through-a-bastion/).
- **EC2 Instance Connect Endpoint is another way.** It is not a server you look after, but a service in a subnet in your VPC.
- **Since it is not a server, there is no operating system to update and no instance that costs per hour.** That is the big difference from a bastion host.

## How it works

- **The endpoint is created in a subnet in the VPC and gets its own security group.** This guide puts it in the private subnet `<prefix>-private-a`, the same subnet as the test server.
- **There can be one endpoint per VPC and per subnet.**
- **The endpoint's security group, `<prefix>-eice-sg`, only needs outbound TCP 22 to the instance's security group.** No inbound rules are needed at all, since it is not the internet that connects to the endpoint but the AWS service.
- **The instance's security group, `<prefix>-private-sg`, lets in port 22 only from the endpoint's group.** It is the same pattern as when a web server lets in SSH only from the bastion's group.
- **You connect with AWS CLI version 2.** The command is `aws ec2-instance-connect ssh`, and it is the CLI that builds the connection through the endpoint. `--instance-id` gives the instance, `--os-user` the user, `ec2-user` as usual on Amazon Linux, and `--connection-type eice` says that the connection should go through the endpoint.
- **Amazon Linux 2023 has EC2 Instance Connect preinstalled,** so no extra software is needed on the server. EC2 Instance Connect sends a temporary key to the server when you connect, so no key pair is needed. See [guide 02](../02-ec2-instance-connect/) for EC2 Instance Connect with a public IP.

## Prerequisites

- A VPC named for example `<prefix>-vpc` with a private subnet named for example `<prefix>-private-a`, without a route to the internet. See [Connect to your instances using a private IP address and EC2 Instance Connect Endpoint](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-with-ec2-instance-connect-endpoint.html).
- AWS CLI version 2 on your computer, signed in. Check with `aws --version`. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- A user that may create security groups, instances and endpoints, for example an administrator. See [Grant permissions to use EC2 Instance Connect Endpoint](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/permissions-for-ec2-instance-connect-endpoint.html).
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your VPC or subnet has another name, use that name instead of `<prefix>-vpc` and `<prefix>-private-a`, and change the settings at the top of `connect-with-endpoint.sh`.

| Placeholder | What it is | Example |
|---|---|---|
| `<instance-id>` | The test server's instance id (EC2, Instances), if you have opened a new terminal | `i-0123456789abcdef0` |
| `<endpoint-id>` | The endpoint's id, starts with `eice-` (VPC, Endpoints) | `eice-0123456789abcdef0` |

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Security groups and test server

[connect-with-endpoint.sh](connect-with-endpoint.sh) is divided into sections that you paste one at a time, since the endpoint is created in the console in between. Keep the same terminal open through all steps: the sections use variables from each other.

1. Open a terminal and paste the settings at the top of the file and section 1. If PREFIX is not set, a warning is printed: set PREFIX and paste again. The settings also print the VPC and subnet names, so that you can check them.
   - It looks up the ids of `<prefix>-vpc` and `<prefix>-private-a` with the Name tag.
   - It creates two security groups with `aws ec2 create-security-group`: `<prefix>-eice-sg` for the endpoint and `<prefix>-private-sg` for the test server. Both ids are printed.
   - A new security group automatically gets an outbound rule that lets out all traffic. The section removes it with `revoke-security-group-egress` and instead adds TCP 22 to `<prefix>-private-sg`.
   - Then `<prefix>-private-sg` gets an inbound rule for 22 from `<prefix>-eice-sg`.
2. Paste section 2. It starts the test server `<prefix>-private-test` with `aws ec2 run-instances` and then waits until it is running.
   - The server is a t3.micro with Amazon Linux 2023, in `<prefix>-private-a`, with the flag `--no-associate-public-ip-address`. It only gets a private address.
   - The file sets `MSYS_NO_PATHCONV=1`, since the AMI is fetched through a path starting with a slash, and Git Bash on Windows would otherwise turn it into a Windows path.
   - No key pair is given. EC2 Instance Connect sends a temporary key to the server when you connect.

### 2. Create the endpoint

1. Go to VPC and choose **Endpoints** in the menu on the left. There may already be other kinds of endpoints in the list.
2. Choose **Create endpoint**. Choose **EC2 Instance Connect Endpoint** as type. Give it a name, for example `<prefix>-eice`, so that it shows clearly in the list.
3. Choose `<prefix>-vpc` as VPC. Under **Security groups**, choose `<prefix>-eice-sg`, and check that no other group is selected. It is the endpoint's group that has the outbound rule to the test server.
4. Choose the subnet `<prefix>-private-a`. Leave **Preserve Client IP** off. Then the traffic to the server comes from the endpoint's address, and that is why the rule from the endpoint's security group works.
5. Create the endpoint at the bottom of the page. It shows in the list with the status **Pending** first, which means that AWS is still building it. It takes a few minutes before the status is **Available**. Wait until it is, otherwise the AWS CLI returns an error. Reload the list now and then.

### 3. Connect and look around

1. When the endpoint is Available, paste section 3. The variable `ID` is still there from section 2, as long as you have not closed the terminal. Otherwise, replace `$ID` with `<instance-id>`.

   ```
   aws ec2-instance-connect ssh --instance-id $ID --os-user ec2-user --connection-type eice
   ```

   After a few seconds you get an ordinary prompt with `ec2-user`, just as with `ssh`.

2. Run `hostname`. The name contains the server's private address. There is no public address to show.

   ```
   hostname
   ```

3. Try to reach the internet. `-m 5` means that `curl` gives up after five seconds.

   ```
   curl -m 5 https://checkip.amazonaws.com
   ```

   No answer comes, since the private subnet has no route out to the internet.

4. Leave the server:

   ```
   exit
   ```

## Check the result

- You got a prompt on a server that has no public address, without going through a bastion host.
- `hostname` shows a private address.
- `curl` gets no answer: you got in, but the server does not get out. That is exactly how a private subnet should work.

## Clean up

Remove everything in this order, in the same terminal as before, since the commands use the variables from the sections. The commands are also at the end of `connect-with-endpoint.sh`.

1. Terminate the test server and wait until it is terminated:

   ```
   aws ec2 terminate-instances --instance-ids $ID
   ```

   ```
   aws ec2 wait instance-terminated --instance-ids $ID
   ```

2. Find the endpoint's id and delete it:

   ```
   aws ec2 describe-instance-connect-endpoints --query 'InstanceConnectEndpoints[].[InstanceConnectEndpointId,State]' --output table
   ```

   ```
   aws ec2 delete-instance-connect-endpoint --instance-connect-endpoint-id <endpoint-id>
   ```

3. Delete the two security groups when the endpoint is gone. The groups refer to each other, so remove the inbound rule in `<prefix>-private-sg` first:

   ```
   aws ec2 revoke-security-group-ingress --group-id $PRIV_SG --protocol tcp --port 22 --source-group $EICE_SG
   ```

   ```
   aws ec2 delete-security-group --group-id $EICE_SG
   ```

   ```
   aws ec2 delete-security-group --group-id $PRIV_SG
   ```

## Endpoint compared with bastion host

| Bastion host | EC2 Instance Connect Endpoint |
|---|---|
| An ordinary instance. It costs as long as it runs, and it must be updated like all other servers, since it is open for SSH from the internet. | A service. It costs nothing extra to have, and there is no operating system to update. Data transfer between Availability Zones can cost, as all traffic between zones. If the endpoint and the server are in the same zone, as in this guide, it is nothing to think about. |
| Ordinary `ssh`. Works with the SSH config, ProxyJump, `scp` and tunnels, see [guide 13](../13-ssh-tunnel-through-a-bastion/), and needs nothing but OpenSSH on your computer. | At most 20 simultaneous connections per endpoint, and a connection lasts at most one hour. |

## Good to know

- **One endpoint per VPC and per subnet.** If you try to create a second endpoint in the same VPC, it does not work, and you should use the one that already exists.
- **With Preserve Client IP off, the server sees the traffic coming from the endpoint's private address.** That is why the rule on the server should point at the endpoint's security group, not at your own public address.
- **The command `aws ec2-instance-connect ssh` is in AWS CLI version 2.** An older version must be updated first.

## Common errors

| Symptom | Cause |
|---|---|
| Timeout when connecting | The inbound rule in `<prefix>-private-sg` or the endpoint's outbound rule in `<prefix>-eice-sg` is missing. Check both groups before looking for errors elsewhere. |
| Error from the AWS CLI directly when connecting | The endpoint is still Pending. Wait until it is Available. |
| `aws ec2-instance-connect ssh` is not found | AWS CLI version 1. Update to version 2. |
| A second endpoint cannot be created | There is already an endpoint in the VPC. Use that one. |
| A security group cannot be deleted | The groups refer to each other, or the endpoint still exists. Remove the inbound rule in `<prefix>-private-sg` first, and wait until the endpoint is deleted. |

## Files

| File | What it is |
|---|---|
| `connect-with-endpoint.sh` | The commands in three sections to paste one at a time: security groups, test server and connection. The clean-up commands are at the end. |
