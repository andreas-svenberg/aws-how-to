# 03 Instance metadata

## What it is

The instance metadata service lets a server ask AWS about itself: which id it has, which availability zone it is in and which addresses it has been given. You fetch a token, ask a few questions, and build a page that shows which server answered.

## Why and when to use it

- **From inside the server you cannot see** the instance id, the zone or the public address. They are known by AWS. The metadata service is the way to ask, and it needs no keys.
- You can get the instance id, the zone, the public and the private address, the instance type and the AMI it was started from, and more.
- **A script can use the answers to adapt itself.** The same user data can, for example, write different information depending on the zone the server ended up in, without anyone typing it in by hand.
- **The same service hands out temporary keys** when the server has an IAM role, see [Role credentials come from here](#role-credentials-come-from-here).
- **A page that shows which server answered** makes load balancing visible.

## How it works

- Every instance reaches a special address, `169.254.169.254`. It is not an ordinary server on the internet, but a service that AWS connects to every instance.
- The address can **only be reached from inside the instance**. From your own computer, nothing happens.
- The answer is plain text, one thing per address. The path `instance-id` gives the instance id, `placement/availability-zone` gives the zone, and so on. Asking for the folder `meta-data` gives a list of everything there is.
- No passwords or keys are needed. Whoever can run commands on the server gets answers, so be careful about who has access to the server.

**IMDSv2: token first**

- Instances started from Amazon Linux 2023 require version 2 of the metadata service, IMDSv2. Version 1 is turned off from the start.
- In version 2 you first fetch a token with a request of type `PUT`, and say how long it should be valid, at most six hours.
- Then you send the token in a header with every question. It is one extra line.
- Without a token the service answers `401 Unauthorized`. That is the most common error when following older guides, which are written for version 1.
- The reason: if a web application has a flaw that lets it be tricked into fetching an address for an attacker, in version 1 it could hand out metadata and the role's keys. The requirement for a `PUT` request with a token stops most such attacks.

## Prerequisites

- An EC2 instance running Amazon Linux 2023 that you can log in to with SSH, or with EC2 Instance Connect (guide 02). See [Get started with Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html).
- For the page in step 4: Apache installed and running, and HTTP (port 80) open in the security group. See [Tutorial: Install a LAMP server on AL2023](https://docs.aws.amazon.com/linux/al2023/ug/ec2-lamp-amazon-linux-2023.html).

| Placeholder | What it is | Example |
|---|---|---|
| `<public-ip>` | The instance's public IPv4 address (EC2, Instances, the instance) | `203.0.113.10` |

## Step by step

All commands are run on the server.

### 1. Fetch a token

1. Connect to the server with SSH, or with EC2 Instance Connect in the browser. It does not matter which.
2. Fetch a token. `-X PUT` sends a `PUT` request to `latest/api/token`. The header says how long the token should be valid, in seconds: 21600 is six hours. The answer is saved in the variable `TOKEN`.

   ```
   TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
   ```

3. Check that the variable has a value. It should print a long line of letters and digits. If the line is empty, something went wrong, usually a typo in the address or the header.

   ```
   echo $TOKEN
   ```

### 2. Save the address and the header in variables

To avoid typing the same long things every time, save the address in `M` and the header with the token in `H`.

```
M=http://169.254.169.254/latest/meta-data
```

```
H="X-aws-ec2-metadata-token: $TOKEN"
```

### 3. Ask about the instance

The answers are written without a newline after them, so the prompt ends up on the same line. That is normal.

Instance id, the same as in the console:

```
curl -s -H "$H" $M/instance-id
```

Availability zone, for example `eu-north-1a`:

```
curl -s -H "$H" $M/placement/availability-zone
```

Public address, the same one you browse to:

```
curl -s -H "$H" $M/public-ipv4
```

Instance type:

```
curl -s -H "$H" $M/instance-type
```

The list of everything there is:

```
curl -s -H "$H" $M/
```

### 4. A page that shows the server

[metadata-page.sh](metadata-page.sh) fetches a token, asks for the instance id and the zone, and writes a new `index.html` with the two values in the text. **Note:** it overwrites `/var/www/html/index.html`. Any page already there is replaced.

1. Get the script to the server. Put it in a public repository and fetch it with `curl`, as in guide 01, or create the file with `nano` and paste the content.
2. Run it. `sudo` is needed since the script writes in Apache's folder.

   ```
   sudo bash metadata-page.sh
   ```

3. Reload `http://<public-ip>` in the browser. The page says which instance and which zone it comes from.

If you start one more server with the same script in user data, after the lines that install and start Apache, it gets its own page with its own id. Two tabs with the two addresses show two different ids. Behind a load balancer, the same idea shows that the answers come from different servers.

## Check the result

- `curl -s -H "$H" $M/instance-id` gives the same id as in the console.
- The page at `http://<public-ip>` shows the instance id and the zone.

## Clean up

The page is the result, so there is nothing to remove in AWS. If you created `metadata-page.sh` on the server, you can remove it:

```
rm metadata-page.sh
```

## Role credentials come from here

- When a server gets a role in IAM, the metadata service hands out temporary keys for the role. They are under `iam/security-credentials/` followed by the role's name. If the server has no role, there is nothing there.

  ```
  $M/iam/security-credentials/<role-name>
  ```

- You never need to fetch them yourself. The AWS CLI and AWS's own libraries automatically look for keys at this address when they run on an instance.
- The keys are valid for a limited time and are replaced automatically before they expire. If such a key leaks, it stops working by itself.
- That is why no access keys should be saved on a server. The role and the metadata service give the server what it needs, and there is nothing to steal that is valid forever.

## Common errors

| Symptom | Cause |
|---|---|
| `401 Unauthorized` | The token is missing, misspelled or has expired. Fetch a new one and check that the header is sent. |
| `curl` waits until it times out | The command is probably run on your own computer and not on the server. The address only exists inside the instance. |
| `401` after logging in again | Variables such as `TOKEN`, `M` and `H` disappear when you log out. Fetch a new token and set the variables again. |
| `404 Not Found` | The path does not exist. Check the spelling, or ask for the folder `meta-data` to see which names exist. |
| A guide on the internet only uses `curl` and the address | It is written for version 1 and does not work on Amazon Linux 2023. |

## Files

| File | What it is |
|---|---|
| `metadata-page.sh` | Writes a page with the instance id and the zone. Run it with `sudo` on the server, or paste it into user data after the lines that install and start Apache. |
