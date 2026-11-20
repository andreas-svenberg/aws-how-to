# 04 Get system log

## What it is

Two ways to troubleshoot a server without logging in to it: the **system log**, what the server wrote to its console when it started, and an **instance screenshot**, a picture of its screen right now. You read the log in the console and with the AWS CLI, look at a screenshot, and practise on a user data script that is wrong on purpose.

## Why and when to use it

- You start a server with user data, wait, and the page does not show. Something has gone wrong, but what?
- The natural thing is to log in and read `/var/log/cloud-init-output.log`. But if the SSH rule is wrong, the key is missing or the server does not come up at all, you cannot log in.
- Then the console can show the system log, what the server wrote to its console during startup. It is read from the outside, from AWS, without anything on the server having to work.
- There is also a screenshot of the server's screen, roughly like looking at the monitor of a physical server in a server room.
- Neither needs a key, a login or an open port in the security group. All that is needed is permission in the console.

## How it works

- A server writes messages to its console when it starts, roughly what you see scroll past on a monitor when a computer boots.
- AWS saves that output shortly after the instance has started, stopped or rebooted. The log can therefore be empty the first minutes after a start.
- It is not updated all the time. What happens an hour later does not necessarily show. The log is mainly for the startup.
- You read it in the console or with the command `get-console-output` in the AWS CLI.
- The screenshot works the same way: it is taken when you ask for it and shows the screen at that moment, nothing more.

## Prerequisites

- An EC2 instance that is running. See [Get started with Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html).
- For the CLI part: the AWS CLI on your computer, or CloudShell. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- For the exercise in step 4: permission to launch an instance, and a security group that allows HTTP (port 80).

| Placeholder | What it is | Example |
|---|---|---|
| `<instance-id>` | The instance's id, starts with `i-` (EC2, Instances) | `i-0123456789abcdef0` |
| `<public-ip>` | The instance's public IPv4 address (EC2, Instances, the instance) | `203.0.113.10` |

## Step by step

### 1. Read the system log in the console

1. Under **Instances**, select the instance. The right instance matters, every instance has its own log.
2. **Actions** at the top right, then **Monitor and troubleshoot** and **Get system log**. A window opens with a long text log.
3. Most of the beginning is the Linux kernel starting, and that can be skipped. The interesting part is towards the end.
4. cloud-init is the program that runs user data. A line that starts with `Cloud-init v.` and ends with `finished at` and a time means that the startup is done. If there are errors or warnings just before it, that is where to start looking.

### 2. The same with the AWS CLI

The whole log as text, the same output that **Get system log** shows in the console, but in your terminal where you can search it:

```
aws ec2 get-console-output --instance-id <instance-id> --output text
```

You can pass it on to `grep` to look for words such as `error` or `failed`.

The latest output is often more interesting than the one saved at the start, for example after a reboot. The flag `--latest` fetches it. It works on instances built on [AWS Nitro](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html), which includes the newer types such as t3.micro.

```
aws ec2 get-console-output --instance-id <instance-id> --latest --output text
```

**In Git Bash on Windows** you may instead get the error `charmap codec can't encode character`. The log contains characters such as an arrow, and the Windows version of the AWS CLI tries to print them with the Windows character table, especially when the output is passed on with a pipe to `grep` or `tail`. Tell the AWS CLI to use UTF-8. Type this once in the terminal, and it applies for the rest of the session:

```
export PYTHONUTF8=1
```

In CloudShell the command works directly.

### 3. Take a screenshot of the server

1. In the same menu, **Actions, Monitor and troubleshoot**, choose **Get instance screenshot**. The instance must be running, a stopped server has no screen to show.
2. The picture shows the server's screen right now. On a server that has started, there is usually a login prompt, and that means the operating system is running.
3. **Download** saves the picture, for example for documentation or when asking for help.

The screenshot is most useful when the server hangs during startup, for example on a disk error. Then you see where it stopped. It is also available in the AWS CLI as `aws ec2 get-console-screenshot`, but the answer is a picture encoded as text, so the console is simpler.

### 4. Exercise: user data that is wrong on purpose

[broken-user-data.sh](broken-user-data.sh) has a typo. The package is called `httpd`, but the script says `httpdd` with two d's. dnf finds no package with that name and gives an error, so the web server is never installed and the page cannot be shown.

1. Launch a new instance. Give it a name you recognise, for example `broken-user-data-test`, and the same settings as your other server. Paste the script under **Advanced details, User data**.
2. Wait a few minutes and browse to `http://<public-ip>`. The page does not answer.
3. Read the system log and scroll towards the end. There you see a chain of errors:
   - First `No match for argument: httpdd` and `Error: Unable to find a match: httpdd` from dnf.
   - Then `Failed to enable unit: Unit file httpd.service does not exist`, since the package was never installed.
   - Then `index.html: No such file or directory`, since the folder `/var/www/html` is created by the httpd package.
   - Last, cloud-init sums up with `Failed to run module scripts-user`.

   The first error causes all the others, so you always start from the top.
4. Notice that the script continued after the first error. That is because it lacks `set -e`. With `set -e` it would have stopped directly at the dnf error.
5. Fix the typo and launch a new instance with the fixed script. User data only runs at the first start, so restarting the old instance does not help.

## Check the result

- The system log of the instance with the fixed script ends with `Cloud-init v. ... finished at ...`, without the errors from step 4.
- `http://<public-ip>` for that instance shows the page.

## Clean up

Terminate the test instances from step 4 when you are done: EC2, Instances, select the instances, **Instance state, Terminate instance**.

## Good to know

- **An empty log** means the server has just started. AWS saves the output a while after start, so wait a few minutes and try again.
- **The log mainly shows the startup.** What happens much later, when the server is already running, usually does not show there.
- **The full output from user data** is always in `/var/log/cloud-init-output.log` on the server. The system log saves the day when you cannot get in, but if you can get in, the file on the server is more complete.
- **The screenshot cannot be typed in.** To type commands, you need SSH, EC2 Instance Connect or the [EC2 serial console](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-serial-console.html), which is a different feature with its own requirements.
- **With several instances,** check that the right one is selected before you fetch the log. The name and the id are at the top of the window.
- **A line about SSM Agent:** `SSM Agent unable to acquire credentials`, *Systems Manager's instance management role is not configured*. It is harmless. It only means that the server has no role for [AWS Systems Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html). It shows on all servers without a role and is not the error you are looking for.

## Common errors

| Symptom | Cause |
|---|---|
| The log is empty | The server has just started. Wait a few minutes. |
| `charmap codec can't encode character` | Git Bash on Windows. Run `export PYTHONUTF8=1` first. |
| No screenshot | The instance is stopped. A stopped server has no screen to show. |
| The log is about another server | The wrong instance is selected. Check the name and the id at the top of the window. |
| The fixed script still gives no page | The old instance was restarted. User data only runs at the first start, so launch a new instance. |

## Files

| File | What it is |
|---|---|
| `broken-user-data.sh` | User data with a deliberate typo (`httpdd`), for practising troubleshooting with the system log. |
