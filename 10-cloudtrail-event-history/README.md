# 10 CloudTrail event history

## What it is

CloudTrail Event history is the account's log of who did what. It exists in every account from the start, and it costs nothing to look in it. You find out who terminated an instance and who created an IAM user, first in the console and then with the AWS CLI.

## Why and when to use it

- An instance has suddenly disappeared. Was it a mistake, a colleague or someone who should not have access? Without a log, you can only guess.
- There is an IAM user that nobody recognises. When was it created, and by whom? That is the first question at a suspected intrusion.
- CloudTrail Event history answers such questions directly. It is on as soon as the account is created, you do not need to set anything up.
- According to AWS's documentation, it costs nothing to look in Event history or to search it with the command `lookup-events`.
- The same log is used both for troubleshooting, for example when something stopped working after a change, and for security, when you want to know who did something.

## How it works

- Every time someone does something in AWS, in the console, with the AWS CLI or from a server with a role, it becomes a call to AWS. CloudTrail records the calls.
- Event history shows the events from the **last 90 days**. Older events disappear from Event history. To keep them longer, you need a [trail](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-create-a-trail-using-the-console-first-time.html).
- Event history contains **management events**: actions that create, change or delete something, such as starting an instance or creating a user.
- The events are stored **in the region where they happened**. An instance started in one region only shows when that region is chosen at the top right.
- IAM is global, and according to AWS, CloudTrail logs IAM events in the region **US East (N. Virginia)**. To see who created a user, you must change to that region.

## Prerequisites

- A user in the console that may read CloudTrail, for example an administrator. See [Working with CloudTrail event history](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html).
- Events to look at: at least one terminated instance and one created IAM user in the last 90 days.
- For the CLI part: the AWS CLI on your computer, or CloudShell. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

| Placeholder | What it is | Example |
|---|---|---|
| `<region>` | The region where your instances run (top right in the console) | `eu-north-1` |

## Step by step

### 1. Who terminated the instance?

1. Search for CloudTrail in the console and choose **Event history** in the menu on the left. Check that `<region>` is chosen at the top right.
2. The list shows events, newest first. Above the list, under **Lookup attributes**, the filter is set to **Read-only** with the value `false`, only events that change something. Change **Read-only** to **Event name**.
3. Type `TerminateInstances`, the name of the call when an instance is terminated. Now the list only shows those events. Notice **User name**. Sometimes it is a user, sometimes `AutoScaling`, when an Auto Scaling group has replaced an instance. It is not always a person who did something.
4. Click an event. There you see **User name**, who did it, and **Event time**, when it happened. On the event's page the time is shown in your local time, while the JSON line `eventTime` further down is in UTC. **Source IP address** and **AWS access key** are also shown.
5. Further down is **Event record**, the whole call in JSON. There you see, among other things, which instance was terminated and from which IP address the call came.

### 2. Who created the user?

1. Choose **US East (N. Virginia)** at the top right. That is where IAM events are logged, even if you always work in another region.
2. Filter on **Event name** again and type `CreateUser`, the call when a new IAM user is created.
3. Now you see the events when users were created, with the user who created them as **User name**. Events older than 90 days no longer show.
4. Also try `AttachGroupPolicy`. It shows when policies were attached to groups.
5. Remember to change back to `<region>` afterwards. Otherwise it looks as if your instances have disappeared the next time you open EC2.

### 3. The same with the AWS CLI

Run it in a terminal on your computer or in CloudShell.

1. Terminated instances, in the region set in your AWS CLI. `--max-items` limits how many events are shown, otherwise the answer gets very long. `--query` picks out time, user and event from the answer, and `--output table` shows it as a table. `--lookup-attributes` says what to search for, with the same attributes as in the console.

   ```
   aws cloudtrail lookup-events --max-items 5 --query "Events[].[EventTime,Username,EventName]" --output table --lookup-attributes AttributeKey=EventName,AttributeValue=TerminateInstances
   ```

   You get five clear rows, and the time is shown in local time.

2. IAM events: change `AttributeValue` to `CreateUser` and add `--region us-east-1`. The flag only applies to that one command.

   ```
   aws cloudtrail lookup-events --region us-east-1 --max-items 5 --query "Events[].[EventTime,Username,EventName]" --output table --lookup-attributes AttributeKey=EventName,AttributeValue=CreateUser
   ```

According to AWS's documentation, you can only search on one attribute at a time. To filter more, do it in the answer with `--query`.

## Check the result

What an event contains:

| Field | What it means |
|---|---|
| Event time | When it happened. The console and the AWS CLI show local time. In Event record, the JSON, `eventTime` is in UTC. |
| User name | Who did it: a user or a role. If a call came from a server with a role, the role's session is shown there, with the instance id as its name (see guide 06). |
| Event source and Event name | The service, for example `ec2.amazonaws.com` or `iam.amazonaws.com`, and the action itself. |
| `sourceIPAddress` | In Event record: the address the call came from. If you do not recognise it, it is worth looking into. |
| `errorCode` | In Event record: the call was denied or failed, for example `AccessDenied`. Failed calls are also logged. A `CreateUser` for a user that already exists, for example, is logged with `errorCode` `EntityAlreadyExistsException`. It is a good way to see whether someone has tried to do something they may not. |

## Clean up

The guide only reads information. There is nothing to remove.

## Good to know

- **Event history shows management events.** Reading or uploading single files in S3 are [data events](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html), and they do not show here.
- **To keep events longer than 90 days,** or to include data events, you need to create a trail that saves the logs in an S3 bucket. It can cost money.

## Common errors

| Symptom | Cause |
|---|---|
| An event you know has happened does not show | Usually the wrong region. Check at the top right before you draw conclusions. |
| No IAM events | IAM events are in US East (N. Virginia), even if you have never worked in that region yourself. |
| A new event does not show | It takes a while before a new event shows in Event history. Wait and reload. |
| Your instances seem to have disappeared in EC2 | You are still in US East (N. Virginia). Change back to your own region. |

## Files

This guide has no files.
