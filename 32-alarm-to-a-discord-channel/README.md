# 32 Alarm to a Discord channel

## What it is

A CloudWatch alarm that sends to an SNS topic can reach more than an inbox. A small Lambda function subscribes to the topic and posts each alarm to a Discord channel through the channel's webhook. The whole team sees the alarm at once, in the chat they already have open. You create the webhook in Discord, create the function, connect it to the topic, and test by forcing an alarm to `ALARM`.

## Why and when to use it

- **E-mail is read when you have time.** An alarm that the site is down can lie unread for an hour.
- **Many teams have a chat open all day.** A new message there is seen directly, often with a notification on the phone.
- **A message in a channel is seen by everyone at the same time,** and everyone sees who answers. If someone writes that they are on it, the rest know the alarm is taken care of.
- **It works on the AWS Free plan.** SMS through SNS does not, see [guide 28](../28-alarm-as-sms-via-sns/). This guide only uses SNS, Lambda and an HTTPS call to Discord.

## How it works

- **The alarm sends to the SNS topic as before.** Nothing changes on the alarm or the topic.
- **The Lambda function becomes a new subscriber on the topic,** next to the e-mail address. Each time the topic gets a message, SNS starts the function and passes the message on.
- **The message from an alarm is JSON** with the alarm's name, new state, description and reason. The function picks out those fields and makes a short text of them.
- **A webhook is an address that Discord gives you for one channel.** Everything posted to it becomes a message in the channel. The function posts the text as JSON over HTTPS, in the field `content`, at most 2000 characters. Discord answers with status `204` when it worked.
- **Anyone with the address can write in the channel.** It is a secret, so it is stored as an environment variable on the function, never in the code.

- **SNS invokes the function asynchronously.** If the function cannot be reached, SNS retries at increasing intervals over several hours.
- **When you add the SNS trigger in the Lambda console,** Lambda sets up both the subscription on the topic and the permission for SNS to invoke the function.

See [Webhook resource](https://docs.discord.com/developers/resources/webhook) in Discord's documentation and [Invoking Lambda Event Functions with Amazon SNS notifications](https://docs.aws.amazon.com/lambda/latest/dg/with-sns.html).

## Prerequisites

- An SNS topic named for example `<prefix>-alarms`, and a CloudWatch alarm named for example `<prefix>-cpu-high` that sends to the topic. See [Using Amazon CloudWatch alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html).
- A Discord server where you may manage webhooks, for example your own server, and a channel for the alarms.
- A user that may create Lambda functions and IAM roles, for example an administrator.
- The AWS CLI on your computer, signed in, or CloudShell. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

If your topic or alarm has another name, use that name instead.

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Create a webhook in Discord

1. Click the cogwheel next to the name of the channel that should get the alarms.
2. Choose **Integrations** in the menu on the left, and click **Create Webhook**. Discord creates a webhook with a name of its own choosing, for the channel you came from.
3. Click the webhook, change **Name** to for example `<prefix>-alarms`, and check that **Channel** is the right channel. The name is shown as the sender of the messages.
4. Click **Save Changes** in the bar that shows up at the bottom.
5. Click **Copy Webhook URL**, and keep the address somewhere temporary until step 2. Do not put it in a file in a repository, in a chat or in a screenshot.

### 2. Create the function

1. Open Lambda in the console, and **check the region at the top right**. It must be the same region as the topic.
2. Click the button **Create an Event Function**, not the arrow next to it.
3. **Author from scratch** is selected. Name the function `<prefix>-discord-alarm`, and choose **Python 3.12** as **Runtime**.
4. Leave **Permissions** as they are. The role that Lambda creates may only write logs, and that is enough, since the function only calls Discord. Click **Create Event Function**.
5. Under the tab **Code**, replace everything in `lambda_function.py` with the content of [send-alarm-to-discord.py](send-alarm-to-discord.py), and click **Deploy**.

### 3. Connect the webhook and the topic

1. Under **Configuration** and **Environment variables**, click **Edit** and **Add environment variable**. **Key** is `DISCORD_WEBHOOK_URL`, and **Value** is the address from Discord. Click **Save**.
2. In the function's overview at the top, click **Add trigger**.
3. Choose **SNS** as the source, choose the topic `<prefix>-alarms`, and click **Add**.

## Check the result

1. Check that the function subscribes to the topic. Replace `<topic-arn>` with the topic's ARN:

   ```bash
   aws sns list-subscriptions-by-topic --topic-arn <topic-arn> --query "Subscriptions[].[Protocol,Endpoint]" --output table
   ```

   The function shows with the protocol `lambda`.

2. Force the alarm to `ALARM`:

   ```bash
   aws cloudwatch set-alarm-state --alarm-name $PREFIX-cpu-high --state-value ALARM --state-reason "Test Discord"
   ```

   Within a few seconds, a message shows in the channel from the webhook's name: the state in bold, the alarm's name, its description and the reason `Test Discord`.

3. Read the function's log:

   ```bash
   aws logs tail /aws/lambda/$PREFIX-discord-alarm --since 5m
   ```

   The line `Discord answered 204` means that Discord accepted the message. In Git Bash on Windows, put `MSYS_NO_PATHCONV=1` first on the line, since the log group's name starts with a slash and Git Bash would otherwise turn it into a Windows path.

At the next evaluation, the alarm goes back to its real state. If the alarm has an OK notification to the topic and goes to `OK`, a second message shows in the channel. An alarm without data goes to `INSUFFICIENT_DATA` instead, and then no second message comes.

## Clean up

Remove everything the guide created, when you no longer want the alarms in Discord:

1. The function's subscription on the topic, in SNS under **Subscriptions**: the one with the protocol `lambda` and the function's ARN as endpoint. AWS recommends deleting subscriptions before the topic, see [Deleting an Amazon SNS topic and subscription](https://docs.aws.amazon.com/sns/latest/dg/sns-delete-subscription-topic.html).
2. The function `<prefix>-discord-alarm` in Lambda.
3. The role that Lambda created for the function, in IAM. Its name starts with the function's name. Remove the managed policy that Lambda created for the role too: its name starts with `AWSLambdaBasicExecutionRole-`.
4. The log group `/aws/lambda/<prefix>-discord-alarm` in CloudWatch Logs.
5. The webhook in Discord: the channel's cogwheel, **Integrations**, the webhook, **Delete Webhook**.

## Other chat services

The same pattern works for other chat services that have webhooks, but each service wants the message in its own format. Only Discord has been tested for this guide.

- **Slack:** create an app, turn on **Incoming Webhooks** and add a webhook for a channel. The text goes in the field `text` instead of `content`. See [Sending messages using incoming webhooks](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks/).
- **Google Chat:** requires a Google Workspace Business or Enterprise account, and webhooks are created in Chat in the browser. The text goes in the field `text`, and a space accepts at most one message per second. See [Build a Google Chat app as a webhook](https://developers.google.com/workspace/chat/quickstart/webhooks).
- **Microsoft Teams:** the old incoming webhooks, built on Office 365 Connectors, stopped working in May 2026. Use **Workflows** in the channel instead. The message is expected as an Adaptive Card, so the code needs more changes than one field name. See [Create Incoming Webhooks](https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook).

## Common errors

| Symptom | Cause |
|---|---|
| `Function not found` when you look for the function in the topic's region | The console was set to another region when the function was created. Delete it there, with its role and policy, and create it again in the topic's region. |
| A message for `ALARM` but none for `OK` | The alarm has no OK notification to the topic, or it went to `INSUFFICIENT_DATA` instead of `OK`. |

## Files

| File | What it is |
|---|---|
| `send-alarm-to-discord.py` | The function's code. Paste it into `lambda_function.py`. |
