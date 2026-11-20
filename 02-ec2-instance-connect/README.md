# 02 EC2 Instance Connect

## What it is

EC2 Instance Connect gives you a terminal on a Linux instance directly in the browser, without a key file. You open the instance's security group for the service, connect in the browser, and do the same from the AWS CLI.

## Why and when to use it

- **No `.pem` file is needed.** The key file and its permissions are what most often causes trouble with SSH.
- **It works from any computer** with a browser that can sign in to the AWS console.
- **It saves the day when the key is lost.** AWS only stores the public part of a key pair, so a lost key file cannot be downloaded again. With Instance Connect you still get in and can rescue what is on the server.
- **Who may connect is controlled in IAM**, not by who happens to have a copy of the key file. It is easier to control, and the logs show who connected.
- **You get an ordinary terminal** as `ec2-user`, in a browser tab. All commands work the same as over SSH.

Use it as a complement to SSH. To copy files with `scp`, or to open the server in an editor over SSH, you still need the key file and ordinary SSH.

## How it works

- When you click **Connect**, a new key pair is created just for that connection. You never see it, and it is not saved anywhere on your side.
- The public part is sent to the instance through AWS, and the Instance Connect software on the server accepts it.
- The key is valid for 60 seconds and is then removed. A connection that has already started continues until you log out, but nobody can use the same key later.
- The software that receives the key is included in the standard Amazon Linux 2023 AMI. In the minimal version it must be installed first.
- The user is `ec2-user`, the same as with SSH.

## Prerequisites

- An EC2 instance running the standard Amazon Linux 2023 AMI, in a public subnet with a public IPv4 address. See [Get started with Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html).
- A user in the AWS console that is allowed to use EC2 Instance Connect. An administrator is. See [Connect to a Linux instance using EC2 Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html).
- For the CLI part: AWS CLI version 2 on your computer, signed in, and a rule in the instance's security group that allows SSH (port 22) from your own IP address. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

| Placeholder | What it is | Example |
|---|---|---|
| `<region>` | The region the instance is in (top right in the console) | `eu-north-1` |
| `<instance-id>` | The instance's id, starts with `i-` (EC2, Instances) | `i-0123456789abcdef0` |

## Step by step

### 1. Open the security group for Instance Connect

The connection from the browser does not come from your computer. It is AWS that connects to the server for you and shows the result in the browser. A rule for your own IP address is therefore not enough. AWS keeps a ready-made list of the service's addresses for each region, a prefix list, which you choose as the source of the rule.

1. In the EC2 console, choose **Security Groups** in the menu on the left and click the instance's security group. Check that the region at the top right is right.
2. Tab **Inbound rules**, **Edit inbound rules**, then **Add rule** at the bottom. You add a rule, you do not change the existing one.
3. **Type** SSH, port 22 is filled in. **Source type** stays on Custom.
4. In the search field under **Source**, type `ec2-instance-connect`. Under **Prefix lists**, two lists show up:
   - `com.amazonaws.<region>.ipv6.ec2-instance-connect`, for IPv6
   - `com.amazonaws.<region>.ec2-instance-connect`, without `ipv6` in the name

   Choose the one **without** `ipv6`, since you connect to the server's IPv4 address. If you choose the wrong list, everything looks right, but the connection still fails. The list is shown as a label under the field when it is chosen.
5. **Save rules.** A green box at the top says that the rules have been changed.

A rule for your own IP address may stay, so that ordinary SSH from your computer still works. Then there are two ways in on port 22, both limited: one from your own address and one from AWS's addresses for Instance Connect.

### 2. Connect in the browser

The console changes its look now and then, so the names of tabs and buttons may differ a little. Look for **EC2 Instance Connect**, that name usually stays.

1. Under **Instances**, tick the box to the far left of the instance. Clicking the name is not enough, it opens the name for editing instead. When the box is ticked, the **Connect** button at the top turns blue. Click it.
2. The page **Connect to instance** has two tabs, **In web browser** and **In SSH client**. Under **In web browser**, choose the card **EC2 Instance Connect**. It is usually already chosen when the instance has a public address.
3. Under **Settings**, **IPv4 address** should be chosen, with the instance's public address. **Username** should be `ec2-user`. Click the orange **Connect** button. A new tab opens with a black terminal window, and after a few seconds you see the Amazon Linux logo and the prompt.
4. Try two commands:

   ```
   whoami
   ```

   ```
   hostname
   ```

5. End with `exit`. It says `logout`, but the page stays black and there is no button to go back. Close the browser tab.

### 3. The same with the AWS CLI

Run the command in a terminal on your own computer, not on the server.

```
aws ec2-instance-connect ssh --instance-id <instance-id>
```

As in the console, a temporary key is created and sent to the instance, and then an ordinary SSH connection starts. No `.pem` file is needed. End with `exit`, and you are back in your own terminal.

Here the connection comes from your own computer, so it is the rule for your own IP address that lets it in, not the prefix list. If you change network, the rule must be updated, just as for ordinary SSH.

## Check the result

- `whoami` answers `ec2-user`.
- `hostname` shows the server's internal name, for example `ip-172-31-35-73`. It is the same server you reach with SSH, just another way in.
- The next time you log in with SSH, `Last login` shows that the browser connection came from an address at AWS, not from your own. That is why the prefix list is needed.

## Clean up

The rule with the prefix list is what makes the browser connection work. If you do not want to use EC2 Instance Connect from the browser, remove it: the security group, **Edit inbound rules**, **Delete** on the rule with the prefix list, **Save rules**.

## Limitations

- **It requires a public IP address.** Servers in private subnets without a public address cannot be reached this way. For those there is EC2 Instance Connect Endpoint, see guide 16.
- **Minimal Amazon Linux AMIs** do not have the software from the start.
- **To copy files with `scp`, or open the server in an editor,** you still need the key file and ordinary SSH. Instance Connect in the browser is a terminal window, nothing more.
- **The prefix list is different in each region.** The name must end with the region the instance is in. A list from another region does not let the service in.

## Common errors

| Symptom | Cause |
|---|---|
| A red box at once: *Failed to connect to your instance. Error establishing SSH connection to your instance. Try again later.* | The rule with the prefix list is missing. The message does not mention the security group, and waiting does not help. Check Inbound rules: that the rule is for port 22, and that the list is the one without `ipv6` in the name. |
| Nothing happens at all | The instance may be stopped. Start it and wait for three of three status checks. The public address changes when it is started again. |
| No option with a public IP address | The instance has no public address, for example because it is in a private subnet. This method does not work then. |
| A message that you lack permission | IAM stops you. It happens with users that only have limited permissions, and it is the right behaviour. |
| You do not get in, although everything else is right | The **Username** field says something other than `ec2-user`. On Amazon Linux it is always `ec2-user`. |
| `NoCredentials`, *Unable to locate credentials* | You ran the CLI command on the server, not on your own computer. The server has no AWS credentials. |
| A warning about *post-quantum key exchange* at the top | It concerns the encryption method between your computer and the server. It does not stop the connection. |

## Files

This guide has no files.
