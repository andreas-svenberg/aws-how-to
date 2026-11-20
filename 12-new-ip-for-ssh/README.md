# 12 New IP for SSH

## What it is

When your public IP address changes, SSH to your server suddenly stops working with `Connection timed out`, although nobody has changed anything in AWS. The reason is that two rules still point at your old address. You find out which address you have now, find the two rules and change the address with the AWS CLI, and then do the same in the console.

## Why and when to use it

- **Your public IP address is the one your internet provider gives you.** At home you have one address, at work or school another, and when your computer shares the network with your phone a third. It can also change at home without warning, for example when the router restarts.
- **SSH is locked to your own address with `/32`,** exactly one address. That is good security, but it also means that the rules stop matching as soon as the address changes.
- **The address is in two places:** the inbound rule for port 22 in the server's security group, and the inbound SSH rule in the public subnet's network ACL. If you only change one of them, it still does not work.
- **The error shows as `Connection timed out`.** ssh waits for an answer that never comes, and gives up after a while. It is not the same as an error with the key, which gives `Permission denied`.
- **A good sign that it is the address:** the web page on the server still works in the browser. Port 80 is open to everyone, so the server is alive. Only port 22 is locked to the old address.

## How it works

- **The security group** is attached to the server's network interface. It has an inbound rule for TCP port 22 with your address and `/32` as the source. If you reach your servers through a bastion host, it is the bastion's security group that has this rule.
- **The network ACL** is attached to the public subnet. Its inbound SSH rule lets in port 22 from the same address. Outbound replies go out through the rule for the high ports, and that one does not need to be touched.
- **An SSH packet from your computer** must first pass the network ACL at the subnet and then the security group at the server. If either says no, the packet never arrives, whatever the other one says.
- **When the packet is stopped, no answer is sent back.** Your computer does not know that the answer was no, it just waits. That is why the error is a timeout and not a clear message that the port is closed.
- **To know which address you have now, ask AWS.** The service checkip answers with the address the call came from, your public address:

  ```
  curl -s https://checkip.amazonaws.com
  ```

  `-s` makes curl print no progress information, only the address. Run it on your own computer to get the right answer.

## Prerequisites

- A VPC with a public subnet and a network ACL, named for example `<prefix>-public-nacl`, with an inbound rule that allows SSH (port 22) from your old address. See [Control subnet traffic with network access control lists](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html).
- A server in the subnet with a security group, named for example `<prefix>-web-sg`, with exactly one inbound rule for port 22 from your old address. See [Security group rules](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html).
- The AWS CLI on your own computer, signed in. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your security group or network ACL has another name, use that name instead in the commands and in `update-ssh-ip.sh`.

| Placeholder | What it is | Example |
|---|---|---|
| `<rule-number>` | The number of the inbound SSH rule in the network ACL (VPC, Network ACLs, Inbound rules) | `120` |
| `<sg-id>` | The security group's id, starts with `sg-` (EC2, Security Groups) | `sg-0123456789abcdef0` |
| `<new-ip>` | Your new public address, from checkip | `203.0.113.10` |

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Change the address with the script

[update-ssh-ip.sh](update-ssh-ip.sh) does everything in one go, so that you can run it again the next time the address changes.

1. Open a terminal on your own computer, in the folder where you saved the script. Check that the AWS CLI is signed in:

   ```
   aws sts get-caller-identity
   ```

   Do not run the script in CloudShell. CloudShell is at AWS and has a public address of its own, so checkip would answer with CloudShell's address. Then you open SSH for CloudShell instead of for yourself.

2. Look at the settings at the top of the file: `SG_NAME`, `NACL_NAME` and `NACL_RULE`. If you reach your servers through a bastion host, change `SG_NAME` to the bastion's security group. If the SSH rule in your network ACL has another number than 120, change `NACL_RULE`.
3. Run the script. It starts by fetching the address from checkip, and if the answer is empty it stops directly with a message. Then it is the network on your computer that is wrong, not AWS.

   ```
   bash update-ssh-ip.sh
   ```

   The script prints the address, the group's id, the rule's id and the network ACL's id as it goes, so that you see what it finds.

4. Read the answer. The change in the security group answers with `Return true`. Last, the group's rules are printed as a table, and there port 22 should have your new address. Then try ssh as usual.

### 2. What the script does

- **The ids are fetched first.** The group is found with `aws ec2 describe-security-groups` and the filter `group-name`. The rule is found with `describe-security-group-rules` and a query that picks the rule where `FromPort` is 22. The query is in single quotes, since the number 22 is in backticks and the shell would otherwise interpret them.
- **The change in the security group** is made with `aws ec2 modify-security-group-rules`, with the group's id and the rule's id. It gives protocol `tcp`, port 22 to 22 and `CidrIpv4` with your address and `/32`. The call replaces the whole rule, not just the address, so protocol and ports must be given every time. When it goes well, AWS answers `Return true`.
- **The change in the network ACL** is made with `aws ec2 replace-network-acl-entry`. It gives the network ACL's id, `--ingress` for inbound, the rule number and `--rule-action allow`. Protocol 6 is the number for TCP in a network ACL. The port range is from 22 to 22, and the cidr block is your address with `/32`. Everything else in the network ACL is left untouched.
- **The script never adds a new rule.** It replaces the rules that already exist. Then the group does not get a long list of old addresses after a few weeks, and the network ACL keeps its numbering.

### 3. The same in the console

1. Go to EC2 and choose **Security Groups** in the menu on the left. If you have many groups, search for `<prefix>` in the search field above the list.
2. Select `<prefix>-web-sg`, or the bastion's security group if you use a bastion host. Choose **Edit inbound rules**.
3. Find the rule for SSH on port 22. In the field **Source**, choose **My IP**, and the console fills in the address that the browser has right now. **Save rules**.
4. Go to VPC and choose **Network ACLs** in the menu on the left. There is no shortcut like My IP here, so have the address from checkip ready.
5. Select `<prefix>-public-nacl` and choose **Edit inbound rules**. Make sure it is inbound and not outbound, it is easy to end up in the wrong one.
6. Change the source of rule `<rule-number>` to your new address followed by `/32`, and save. Leave the rule number and the port as they are. Then try ssh again.

## Check the result

1. `Return true` from `modify-security-group-rules` means that AWS has accepted the change. `replace-network-acl-entry`, on the other hand, prints nothing at all when it goes well, so it has to be checked in another way.
2. Show the security group's rules. The script does it last, but you can also run it yourself:

   ```
   aws ec2 describe-security-group-rules --filters Name=group-id,Values=<sg-id> --output table
   ```

   Find the row where `FromPort` is 22. The column `CidrIpv4` should show your new address with `/32`. If the old address is still there, the change did not go through.
3. Check the network ACL in the console, under **Network ACLs**.
4. Last: ssh to the server. The prompt should come directly. If it waits long and times out again, you have probably only changed one of the two places.

## Clean up

The guide replaces two existing rules and creates nothing new. There is nothing to remove.

## Common errors

| Symptom | Cause |
|---|---|
| Still `Connection timed out` after the script | The script or checkip was run in CloudShell. Then SSH is opened for an address at AWS, and you are still locked out. Always run it on the computer you will connect from. |
| Still `Connection timed out` after a change in the console | Only one of the two places was changed. Both the security group and the network ACL must have the new address. |
| The bastion design stopped working | With a bastion host, the web server's security group only lets in SSH from the bastion's group. Running the script with the web server's group overwrites that rule with your address. Change `SG_NAME` to the bastion's security group first. |
| *Could not read your public IP* | curl got no answer, so the address is empty. The script stops instead of writing an empty address in the rules. Check that the computer has internet and run again. |
| *Expected exactly one port 22 rule* | The security group has no rule or several rules for port 22. The script only changes a group with exactly one. |
| The query fails with a strange error | The query contains backticks around 22. Inside double quotes, the shell tries to run what is between the backticks as a command. With single quotes, the text is passed unchanged to the AWS CLI. |

## Files

| File | What it is |
|---|---|
| `update-ssh-ip.sh` | Fetches your public address and replaces the SSH rule in the security group and in the network ACL. Run it on your own computer. |
