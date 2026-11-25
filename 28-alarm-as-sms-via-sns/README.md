# 28 Alarm as SMS via SNS

## What it is

An SNS topic that sends e-mail when a CloudWatch alarm goes off is a good start. But e-mail is read when you have time, and an alarm that the site is down needs to reach someone directly. Then SMS is a better choice. You verify a phone number in the SNS sandbox for SMS, add an SMS subscription to the alarm topic and test by forcing an alarm to `ALARM`. You need your mobile phone.

**SMS requires an AWS account with the Paid plan.** When this was tested on an account with the Free plan, SNS could not send SMS at all. With the Free plan, see [guide 32](../32-alarm-to-a-discord-channel/) for alarms in a chat channel instead.

## Why and when to use it

- **An alarm that nobody sees is worth as much as no alarm at all.**
- **E-mail ends up in an inbox together with everything else.** You read it when you have time, and on a day off maybe not at all. An SMS shows on the phone's screen directly, even when you are not at the computer.
- **Not every alarm is urgent.** If the site is down on a Saturday evening, customers notice it, and someone needs to know within minutes. If an alarm warns that a disk is filling up, it can wait until Monday morning. An e-mail is enough, and an SMS in the middle of the night would mostly be annoying.
- **SMS costs money per message,** in a way that e-mail does not in small amounts. So send SMS only for what is really urgent, not for every alarm that changes state.
- **An SNS topic can have several subscriptions of different kinds.** The same topic can send both e-mail and SMS. This guide adds SMS to the same topic. In production, you would often make a separate topic for the urgent alarms.

## How it works

- **New accounts have SMS in a sandbox.** It is a protection against new accounts being used to send spam SMS to unknown numbers.
- **In the sandbox, you can only send SMS to numbers you have first verified with a code,** and you can have at most 10 such numbers. For trying it out, your own number is enough.
- **The verification applies per region.** A number verified in another region does not exist in the region of your topic. Always check the region at the top right before you start.
- **The account has a limit for how much SMS may cost per month,** and it is low by default. When the limit is reached, SNS stops sending SMS, which protects against an expensive surprise. See [Setting SMS messaging preferences in Amazon SNS](https://docs.aws.amazon.com/sns/latest/dg/sms_preferences.html).
- **To get out of the sandbox** and send to any number, you open a case with AWS Support and describe how you will use SMS. That is not needed for this guide.
- **Behind the scenes, SNS sends its SMS through AWS End User Messaging SMS.** You may come across that name in the console or the documentation, but everything in this guide is done from SNS. When this was tested, an account with the Free plan had no access to AWS End User Messaging SMS, and that is why SMS requires the Paid plan.

See [Using the Amazon SNS SMS sandbox](https://docs.aws.amazon.com/sns/latest/dg/sns-sms-sandbox.html).

## Prerequisites

- An AWS account with the Paid plan. On the Free plan, SMS cannot be used.
- An SNS topic named for example `<prefix>-alarms`, with a confirmed e-mail subscription, and a CloudWatch alarm named for example `<prefix>-cpu-high` that sends to the topic. See [Using Amazon CloudWatch alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html).
- A mobile phone that can receive SMS.
- The AWS CLI on your computer, signed in, or CloudShell. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your topic or alarm has another name, use that name instead, and change the settings at the top of `test-sms-alarm.sh`.

| Placeholder | What it is | Example |
|---|---|---|
| `<phone-number>` | Your mobile number in international format, with `+` and the country code, without the leading zero and without spaces | `+46701740605` |

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Verify the number

Before SNS can send anything to the number, it must be verified.

1. Open Amazon SNS in the console and check that the region at the top right is the one where your topic is.
2. Choose **Text messaging (SMS)** in the menu on the left. There you see the account's settings for SMS, and that the account is in the sandbox.
3. Find the section **Sandbox destination phone numbers** and click **Add phone number**. The list is empty the first time.
4. Choose the country code, type your mobile number without the leading zero, choose the language for the verification message and click **Add phone number**. Now AWS sends an SMS with a code.
5. Type the code from the SMS in the box **Verification code** and click **Verify phone number**. The number is now shown as verified in the list. If no code arrives, see Common errors.

### 2. Subscribe to the topic

Now connect the number to the topic, in the same way as an e-mail address.

1. Choose **Topics** in the menu on the left and click on `<prefix>-alarms`. You see the tab **Subscriptions** with the e-mail subscription.
2. Click **Create subscription**. The topic's ARN is already filled in, since you came from the topic.
3. Choose **SMS** as **Protocol**. In **Endpoint**, type `<phone-number>` in international format. The most common error is that the leading zero of the mobile number is included: a Swedish number `070 174 06 05` is written `+46701740605`, without the zero and without spaces or dashes.
4. Click **Create subscription** and go back to the topic. The new subscription should show in the list with the protocol **SMS** and your number.

The e-mail subscription is not affected. The topic now has two subscriptions, and every message to the topic goes to both.

### 3. Test the alarm

You test without putting load on any server, by setting the alarm's state by hand. [test-sms-alarm.sh](test-sms-alarm.sh) contains the command, and also a command that lists the subscriptions on the topic so that you can check that SMS is there:

```
bash test-sms-alarm.sh
```

The command that forces the alarm is:

```
aws cloudwatch set-alarm-state --alarm-name ${PREFIX}-cpu-high --state-value ALARM --state-reason "Test SMS"
```

- **`set-alarm-state` changes an alarm's state directly,** without looking at any metrics.
- **The alarm name must match exactly,** otherwise you get an error that the alarm does not exist.
- **`--state-value ALARM`, in capitals,** is the state you want to set the alarm in.
- **`--state-reason` is required.** It shows in the alarm's history, so that nobody believes that the server really had high CPU.

## Check the result

- Within a minute or so, both an e-mail and an SMS should arrive.
- At the next evaluation, CloudWatch calculates the state from the metrics again, and then the alarm goes back to `OK` by itself.

## Clean up

Remove the SMS subscription from the topic when you no longer need it, and preferably the verified number too. Then no more SMS can arrive, whatever happens with the alarms.

1. In SNS, choose **Topics**, click on `<prefix>-alarms`, select the SMS subscription under **Subscriptions** and choose **Delete**.
2. Under **Text messaging (SMS)**, select the number under **Sandbox destination phone numbers** and delete it. A number can only be deleted when at least 24 hours have passed since it was verified.

## What can an SMS cost?

SMS is the part of alarm notifications where every single message costs something noticeable.

- **The price per SMS depends on the country of the recipient.** See [Amazon SNS pricing](https://aws.amazon.com/sns/pricing/) before you use SMS for anything real.
- **The spend limit is a good protection.** When it is reached, SNS stops sending SMS for the rest of the month, instead of going on and sending an invoice. The limit is changed under **Text messaging (SMS)**, in the section **Text messaging preferences**, with the button **Edit**, in the field **Account spend limit**.
- **The big risk is an alarm that flips back and forth,** for example a CPU alarm with too low a threshold. Every time it goes to `ALARM`, an SMS is sent, and in one night it can be very many.
- **Therefore: SMS only for what is urgent,** such as the site being down. Everything else goes by e-mail. It saves both money and whoever has the phone.

## Good to know

- **Phone numbers are personal data.** Never write them in a script, a template or a README that ends up in a repository. The test script therefore contains no number at all: the number is only in the console and in your account.
- **A sender ID is the name shown as sender of the SMS** instead of a number. Support varies by country, and some countries require registration. In Sweden, for example, sender IDs are supported without registration. A sender ID can be 1 to 11 characters (at least 3 recommended), must contain at least one letter, and may only use letters, digits and dashes. This guide does not use one. See [Sender IDs in AWS End User Messaging SMS](https://docs.aws.amazon.com/sms-voice/latest/userguide/sender-id.html).

## Common errors

| Symptom | Cause |
|---|---|
| Under **Text messaging (SMS)**, **Account information** says `The AWS Access Key Id needs a subscription for the service`, and the AWS CLI answers `SubscriptionRequiredException` | Seen on an account with the Free plan. SMS requires the Paid plan. See [guide 32](../32-alarm-to-a-discord-channel/) for an alternative. |
| No code after 15 minutes | Check that the number is written correctly, without the leading zero. Then click **Resend verification code** at the number in the list. You can ask for a new code at most five times in 24 hours. |
| The number is missing in the list | It was verified with another region selected at the top right. It only exists there. Change region and verify again. |
| No SMS arrives when the alarm goes off | The subscription has the leading zero in the number, the number is not verified in the topic's region, or the spend limit has been reached. |
| An error that the alarm does not exist | The alarm is not called `<prefix>-cpu-high`. Change `ALARM_NAME` at the top of the script. |

## Files

| File | What it is |
|---|---|
| `test-sms-alarm.sh` | Lists the subscriptions on the topic and forces the alarm to `ALARM`, so that both e-mail and SMS are sent. |
