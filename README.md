# aws-how-to

Short, practical guides for common tasks in Amazon Web Services. Each guide
is self-contained: what it is, when to use it, what you need before you
start, step-by-step instructions, how to check the result and how to clean
up afterwards.

## Before you start

- Resource names are written with a prefix of your own choice, for example
  `<prefix>-web`. Set it once in the terminal: `export PREFIX=demo`.
  `export` is needed so that scripts you run with `bash` also see the prefix.
- Set your region once in the terminal: `REGION=eu-north-1`, and use the
  same region in the console.
- Placeholders are written in angle brackets, for example `<public-ip>`.
  Replace the whole placeholder, brackets included.

## Guides

| # | Guide | What it does |
|---|-------|--------------|
| 01 | [Fetch a web page from GitHub](01-fetch-a-web-page-from-github/) | Let a web server fetch its page from a public GitHub repository with `curl`, by hand or automatically with user data. |
| 02 | [EC2 Instance Connect](02-ec2-instance-connect/) | Open a terminal on an instance in the browser, without a key file, and do the same from the AWS CLI. |
| 03 | [Instance metadata](03-instance-metadata/) | Ask the instance metadata service (IMDSv2) about the instance itself, and build a page that shows which instance answered. |
| 04 | [Get system log](04-get-system-log/) | Troubleshoot an instance without logging in, with its system log and a screenshot, and practise on user data that is broken on purpose. |
| 05 | [Files in CloudShell](05-files-in-cloudshell/) | Move files between your computer and CloudShell, pack several files into one, and use git in CloudShell. |
| 06 | [Temporary credentials from a role](06-temporary-credentials-from-a-role/) | See how an IAM role gives an instance temporary credentials through the metadata service, and how they are rotated automatically. |
| 07 | [Last accessed information](07-last-accessed-information/) | See when a user, group or role last used each service it has access to, and remove permissions that are never used. |
| 08 | [Credential report](08-credential-report/) | Get a report of all IAM users in one table: who has MFA, who has access keys and when they were last used. |
| 09 | [Require MFA in a policy](09-require-mfa-in-a-policy/) | Make MFA a rule that IAM checks: without MFA the user is denied, with MFA everything works as usual. |
| 10 | [CloudTrail event history](10-cloudtrail-event-history/) | Find out who did what in the account, for example who terminated an instance or created a user, in the console and with the AWS CLI. |
| 11 | [Profiles in the AWS CLI](11-profiles-in-the-aws-cli/) | Keep several identities signed in in the same terminal and choose which one each command uses. |
| 12 | [New IP for SSH](12-new-ip-for-ssh/) | Find the two rules (security group and network ACL) that still point at your old IP address when SSH stops working, and update them. |
| 13 | [SSH tunnel through a bastion](13-ssh-tunnel-through-a-bastion/) | Forward a local port through a bastion host to a service that is not open to the internet, and save the tunnel in the SSH config. |
| 14 | [VPC Flow Logs, see rejected traffic](14-vpc-flow-logs-see-rejected-traffic/) | Log rejected traffic in a VPC and search it with CloudWatch Logs Insights, to see what was stopped, from where and on which port. |
| 15 | [Reachability Analyzer](15-reachability-analyzer/) | Let AWS analyse the path to an instance through security groups, network ACLs and route tables, and point out what blocks it. |
| 16 | [EC2 Instance Connect Endpoint](16-ec2-instance-connect-endpoint/) | Connect with SSH to an instance in a private subnet without a bastion host and without a public IP. |
| 17 | [Database in a graphical client](17-database-in-a-graphical-client/) | Open a private database in a graphical tool on your computer through an SSH tunnel. |
| 18 | [Share a file with a presigned URL](18-share-a-file-with-a-presigned-url/) | Share a single file from a private bucket with a link that stops working after a time you choose. |
| 19 | [Copy uploads to S3 with sync](19-copy-uploads-to-s3-with-sync/) | Copy uploaded files from a web server to S3 with `aws s3 sync`, where later runs only copy what is new or changed. |
| 20 | [Static website on S3](20-static-website-on-s3/) | Let S3 serve a website made of ready-made files, without any server, and see why this is the only bucket that should be public. |
| 21 | [cfn-lint in VS Code](21-cfn-lint-in-vs-code/) | Find errors in a CloudFormation template before deploying it, in VS Code and in the terminal, and compare with `validate-template`. |
| 22 | [Stack termination protection](22-stack-termination-protection/) | Protect a CloudFormation stack from being deleted by mistake, and compare with DeletionPolicy in the template. |
| 23 | [Which server answers?](23-which-server-answers/) | A small PHP page on shared storage shows which instance and zone behind a load balancer answered the request. |
| 24 | [Fewer servers at night](24-fewer-servers-at-night/) | Use scheduled actions to scale an Auto Scaling group down in the evening and up again on weekday mornings. |
| 25 | [Load test with ab](25-load-test-with-ab/) | Send HTTP requests through a load balancer with ApacheBench in CloudShell, and read response times and errors. |
| 26 | Sticky sessions | Keep a visitor on the same server with load balancer stickiness, and see why stateless servers are the better solution. |
| 27 | Fixed response from the load balancer | Add a listener rule that lets the load balancer answer itself, for example with a maintenance page, without asking any server. |
| 28 | Alarm as SMS via SNS | Add an SMS subscription to an SNS topic so that urgent alarms reach a phone, not only an inbox. |
| 29 | Run a Lambda from the browser | Give a Lambda function its own web address with a function URL, call it from the browser and the terminal, and understand the risk of an open address. |
| 30 | Composite alarm | Combine other alarms into one that only alerts when a rule is met, for example when two things are wrong at the same time. |

## License

MIT, see [LICENSE](LICENSE).
