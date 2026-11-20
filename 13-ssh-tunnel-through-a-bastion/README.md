# 13 SSH tunnel through a bastion

## What it is

With a bastion host you can log in to a web server through a jump, but SSH can also carry other traffic through the same encrypted connection. That is called local port forwarding, and it is a way to reach services that are not open to the internet. You open a tunnel from a port on your own computer, through the bastion, to port 80 on the web server's private address, and show the web page on `localhost`. Then you put the same thing in your SSH config.

## Why and when to use it

- **Only the bastion accepts SSH from your address.** The web server only accepts SSH from the bastion's security group, which is exactly how it should be.
- **Some services you want to reach from your own computer with a program of your own,** for example a web browser or a database tool. A private address in the VPC cannot be reached directly from the internet.
- **An SSH tunnel solves it.** You tell ssh to listen on a port on your own computer and send everything that arrives there through the encrypted connection to the bastion, and on from there.
- **Nothing new needs to be opened.** The bastion already lets in SSH from your address, and nothing more is needed. No new rule in the security groups or in the network ACL.
- **The same technique works for a database in a private subnet,** see [guide 17](../17-database-in-a-graphical-client/).

## How it works

```
ssh -N -L 8080:<private-ip>:80 <prefix>-bastion
```

- This is ordinary OpenSSH, the same ssh you already use, not a service in AWS.
- `-L` means local port forwarding. First comes the port on your own computer, here 8080. Then comes the target's address and port. The address is resolved **from the bastion**, not from your computer, which is why a private address works.
- Last comes `<prefix>-bastion`, the name from your SSH config. You log in to the bastion, and it is the bastion that sends the traffic on to the web server.
- `-N` means that ssh should not start a shell on the bastion. You get no prompt, and the terminal seems to hang. That is right: the tunnel is up as long as the command runs.
- The traffic from your computer to the bastion goes encrypted inside the SSH connection. From the bastion to the web server's private address it goes as ordinary traffic inside the VPC, the same way as when the bastion itself calls the web server.
- **Ctrl+C** ends ssh, and with it the tunnel. After that, nothing answers on port 8080 on your computer any more.

## Prerequisites

- A bastion host in a public subnet that you can log in to with SSH, and a web server in the same VPC with a web server answering on port 80. See [Get started with Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html).
- The web server's security group lets in port 80 from the bastion. See [Security group rules](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html).
- An SSH config (`~/.ssh/config`) on your computer with a block `Host <prefix>-bastion`, so that `ssh <prefix>-bastion` works.

| Placeholder | What it is | Example |
|---|---|---|
| `<prefix>` | The prefix in your resource and host names, see the root README | `demo` |
| `<private-ip>` | The web server's private IPv4 address (EC2, Instances, the instance) | `10.0.1.25` |
| `<bastion-public-ip>` | The bastion's public IPv4 address | `203.0.113.10` |
| `<key>` | The name of your key file, without `.pem` | `my-key` |

## Step by step

### 1. Find the web server's private address

1. Go to EC2 and choose **Instances** in the menu on the left. Check that both the bastion and the web server are **Running**.
2. Select the web server. Under the details, its private IPv4 address is shown. That is the address to use, not the public one.

   You may already have the address in another place: in `~/.ssh/config`, on the line `HostName` in the web server's block, if you log in to it through the bastion with `ProxyJump`.

3. Check that the login to the bastion works, before you bring in the tunnel. Otherwise you do not know what is wrong if the tunnel does not come up. ssh logs in, runs `hostname` on the bastion and logs out directly.

   ```
   ssh <prefix>-bastion hostname
   ```

   If you get a host name back without having to answer anything, your SSH config and key are in order. If it times out, your address may have changed, see [guide 12](../12-new-ip-for-ssh/).

### 2. Start the tunnel

1. Open a terminal on your own computer. The tunnel must always be started where the browser is, since it is on that computer that port 8080 should be opened.

   ```
   ssh -N -L 8080:<private-ip>:80 <prefix>-bastion
   ```

   Nothing visible happens, the cursor just blinks. That is exactly what `-N` should give. Leave the window open: if you close it, the tunnel closes.

2. Open the browser on the same computer:
   - http://localhost:8080

   It is http, not https, since the tunnel goes to port 80. The web server's start page is shown. The browser thinks it is talking to your own computer, but the request goes through the tunnel to the bastion and from there to the web server's private address.

3. Go back to the terminal and press **Ctrl+C**. Reload the page in the browser: now you get an error that the connection was refused. The tunnel is gone.

### 3. LocalForward in your SSH config

If you use the tunnel often, it is easier to write it into your SSH config.

1. Open the file `config` in the folder `.ssh` in your home folder. Leave the existing blocks for the bastion and the web server.
2. Copy the block from [ssh-config-tunnel.txt](ssh-config-tunnel.txt) and paste it last in the file. Fill in the bastion's public address on the line `HostName`, your key file on the line `IdentityFile` and the web server's private address on the line `LocalForward`.

   The block is called `Host <prefix>-web-tunnel`. It is a name of its own, so that an ordinary login with `ssh <prefix>-bastion` does not open the tunnel every time. That would give an error if the port is already in use.

   The line `LocalForward 8080 <private-ip>:80` does the same as `-L` in the command. Notice that there is a space after 8080 here, not a colon.

3. Start it. `-N` is still written on the command line, so that you get no prompt.

   ```
   ssh -N <prefix>-web-tunnel
   ```

4. Open http://localhost:8080 again. The same start page should show, and **Ctrl+C** ends it as before.

## Check the result

- http://localhost:8080 shows the web server's start page while the tunnel is running.
- After **Ctrl+C**, the same address gives an error that the connection was refused.

## Clean up

The tunnel only exists as long as ssh runs, and **Ctrl+C** closes it. Nothing is created in AWS. If you do not need the block `Host <prefix>-web-tunnel` any more, remove it from `~/.ssh/config`.

## A tunnel compared with an open port

| Open port | Tunnel |
|---|---|
| Needs a rule in the security group and one in the network ACL for every service. Every new service gives two new rules to keep track of. | Only SSH to the bastion needs to be open, and that rule already exists. The number of openings to the internet does not grow when you add more services. |
| Anyone on the internet can try to connect. Public addresses are knocked on all the time, and a database that answers on the internet is a known target. | You must first log in to the bastion with SSH, and that requires the key. Without the key, nobody gets further than the login. |
| The rule stays until someone removes it. | The tunnel only exists as long as ssh runs. When you press Ctrl+C, the way is closed again, and there is no rule that someone forgets to remove afterwards. |

## Good to know

- **The address in `-L` is seen from the bastion.** If you write `localhost` there, it means the bastion itself, and then you get the bastion's port 80, where there is no web server. Use the web server's private address.
- **The traffic from the bastion to the web server must be let in by the web server's security group.** If the bastion and the web server are in the same subnet, the network ACL is not checked for the traffic between them.
- **`-L` and `LocalForward` are ordinary OpenSSH features,** not something AWS has invented. The same technique works against any server.

## Common errors

| Symptom | Cause |
|---|---|
| An error that the address is already in use | Another program already listens on port 8080 on your computer. Change to, for example, 8081, both in the command and in the browser. |
| The browser cannot reach `localhost:8080` | The tunnel was started in CloudShell or on another computer. Then port 8080 is opened there. Start it on the computer where the browser is. |
| The tunnel is up but the page does not answer | The address in `-L` is wrong, for example `localhost`, or the web server's security group does not let in port 80 from the bastion. |
| `ssh <prefix>-bastion hostname` times out | Your public address may have changed, see [guide 12](../12-new-ip-for-ssh/). |

## Files

| File | What it is |
|---|---|
| `ssh-config-tunnel.txt` | A block to add to `~/.ssh/config`, which opens the tunnel with `ssh -N <prefix>-web-tunnel`. |
