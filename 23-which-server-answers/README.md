# 23 Which server answers?

## What it is

A small PHP page that shows the instance id and availability zone of the server that answered. You put it once on storage shared by all servers behind a load balancer, and reload it to see which server answers each time.

## Why and when to use it

- Two servers behind a load balancer return exactly the same page, so you cannot see which one answered, or whether the load is shared at all.
- The target group says that both servers are healthy, but not that both actually get requests.
- A page that tells you who it is shows it: when you reload, the answer switches between two instance ids and two zones.

## How it works

- The page is placed on storage that all servers mount (for example EFS). A file put there on one server exists on every server at once, also on new servers that the group starts later.
- The file is PHP, and it is run by the server that receives the request. The code is the same everywhere, but it runs on different machines.
- The code asks the instance metadata service (IMDSv2, see [guide 03](../03-instance-metadata/)) for the server's own instance id and zone: first a PUT to `api/token`, then two GET requests with the token in a header.

## Prerequisites

- An Application Load Balancer, named for example `<prefix>-alb`, with a listener on HTTP port 80 that forwards to a target group. See [Create an Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-application-load-balancer.html).
- An Auto Scaling group (or at least two instances) in the target group, with two healthy servers in different availability zones. See [Tutorial: Set up a scaled and load-balanced application](https://docs.aws.amazon.com/autoscaling/ec2/userguide/tutorial-ec2-auto-scaling-load-balancer.html).
- Apache with PHP on the servers. See [Tutorial: Install a LAMP server on AL2023](https://docs.aws.amazon.com/linux/al2023/ug/ec2-lamp-amazon-linux-2023.html).
- A folder under the web root that is shared by all servers, for example an EFS file system. See [Mounting on EC2 Linux instances using the EFS mount helper](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-mount-helper-ec2-linux.html).
- SSH access to one of the servers, and the key file `<key>.pem`.
- The AWS CLI in a terminal on your computer, or CloudShell.
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

| Placeholder | What it is | Example |
|---|---|---|
| `<shared-folder>` | The shared folder, under Apache's web root `/var/www/html` | `/var/www/html/shared` |
| `<url-path>` | The same folder as seen from the browser: the part after `/var/www/html/` | `shared` |
| `<server-ip>` | Public IP of one of the servers (EC2, Instances) | `203.0.113.10` |
| `<alb-dns>` | The load balancer's DNS name (step 2 below) | `demo-alb-1234567890.eu-north-1.elb.amazonaws.com` |

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Put the page on the shared storage

1. Copy the file to the home folder on one of the servers. It does not matter which one, since the file ends up on shared storage.

   ```
   scp -i ~/.ssh/<key>.pem which-server.php ec2-user@<server-ip>:~
   ```

   If you only reach the servers through a bastion host, scp works with the same SSH config and ProxyJump that you use for ssh.

2. Log in to the same server.

   ```
   ssh -i ~/.ssh/<key>.pem ec2-user@<server-ip>
   ```

3. Copy the file to the shared folder. `sudo` is needed, since ec2-user may not write in the web server's folders.

   ```
   sudo cp which-server.php <shared-folder>/which-server.php
   ```

4. Optional: check with `ls` on another server that the file is there too.

   ```
   ls -l <shared-folder>/which-server.php
   ```

### 2. Reload in the browser

1. Get the load balancer's DNS name.

   ```
   aws elbv2 describe-load-balancers --names "${PREFIX}-alb" --query 'LoadBalancers[0].DNSName' --output text
   ```

   If your load balancer has another name, use that name instead of `${PREFIX}-alb`.

2. Open `http://<alb-dns>/<url-path>/which-server.php` in the browser. Use http, not https, when the listener only listens on port 80.
3. Reload a few times with F5 and read the instance id and zone each time.

### 3. Six requests with curl

```
for i in 1 2 3 4 5 6; do curl -s http://<alb-dns>/<url-path>/which-server.php; echo; done
```

Or run the script, which does the same. Open `which-server-loop.sh` first and change `PAGE_PATH` to the same path as in the browser, for example `shared/which-server.php`. The script looks up the DNS name of `<prefix>-alb` itself, or you give it as an argument.

```
bash which-server-loop.sh
```

```
bash which-server-loop.sh <alb-dns>
```

## Check the result

- Two different instance ids, the two servers in the target group. Compare with the Targets tab of the target group.
- Two zones, for example eu-north-1a and eu-north-1b.
- The order is not always strictly every other server. The load balancer has nodes in each zone that distribute on their own. Over many requests it evens out.
- Only one id, even after many requests? Check that both targets are healthy. A server that is not healthy gets no requests.

## Clean up

The page tells anyone on the internet your instance ids and zones. Remove it when you are done, logged in on any of the servers:

```
sudo rm <shared-folder>/which-server.php
```

It disappears from all servers at once. Check with curl that the address no longer answers with an instance id.

## Common errors

| Symptom | Cause |
|---|---|
| The page says it could not get a token | PHP does not reach the metadata service. Test the same with curl directly on the server, with a token, to see whether PHP or the metadata service is the problem. |
| Only one instance id | Only one healthy target. Check the Targets tab. |

## Files

| File | What it is |
|---|---|
| `which-server.php` | The PHP page. Copy it to the shared folder. |
| `which-server-loop.sh` | Asks the load balancer six times which server answers. |
