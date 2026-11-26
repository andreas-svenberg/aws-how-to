# 30 Composite alarm

## What it is

A composite alarm does not look at metrics but at other alarms. With several alarms on the same topic, quite a lot of notifications arrive, and many of them do not mean that anything is seriously wrong. A composite alarm only goes off when a rule is met, for example when two things are wrong at the same time. You create a composite alarm in the console and one with the AWS CLI, test it by setting two alarms to `ALARM` by hand, and look at advantages and risks. The alarms that already exist are not changed.

## Why and when to use it

- **A single alarm often says too little about how serious the situation is.** A CPU alarm can go off when an Auto Scaling group is just starting another server, or when someone uploads many images. The site works anyway.
- **High CPU while the site check says that the site does not answer is a real problem.** It is the combination that is interesting, not each alarm on its own.
- **A composite alarm is an alarm whose state is calculated from other alarms' states.** It has no metric and no threshold of its own, only a rule. It goes to `ALARM` only when the rule is met, and can then send to an SNS topic just like an ordinary alarm.
- **The result is fewer notifications.** An alarm that sends mail every day without anything being wrong teaches you to ignore the mail, and then you miss the one that actually means something.

## How it works

- **The rule is built from other alarms' states.** Each part asks whether a certain alarm is in a certain state right now. There is one function per state: `ALARM`, `OK` and `INSUFFICIENT_DATA`, with the alarm's name in parentheses. The name can be in double quotes, but does not have to be.
- **The parts are combined with `AND`, `OR` and `NOT`,** and with parentheses when the rule gets longer. `AND` means that both must be true, `OR` that at least one must be, and `NOT` turns a condition around.
- **`AT_LEAST` is true when at least a number of alarms in a list are in a state,** for example `AT_LEAST(2, ALARM, (alarm1, alarm2, alarm3, alarm4))`. The number can also be a percentage, such as `50%`. See [Composite alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarm-combining.html).
- **The rule used with the AWS CLI in this guide** is true only when both alarms are in `ALARM` at the same time:

  ```
  ALARM("<prefix>-site-check") AND ALARM("<prefix>-cpu-high")
  ```

- **When the rule becomes true, the composite alarm goes to `ALARM`** and runs its actions, just like an ordinary alarm.
- **All alarms in the rule must be in the same account and region as the composite alarm.** A composite alarm can also use other composite alarms in its rule.

See [PutCompositeAlarm](https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/API_PutCompositeAlarm.html).

## Prerequisites

- An SNS topic named for example `<prefix>-alarms`, with a confirmed e-mail subscription.
- Metric alarms that the composite alarm can combine. This guide uses three:
  - `<prefix>-site-check`: the site does not answer, see [guide 31](../31-site-check-with-lambda/).
  - `<prefix>-cpu-high`: high CPU in an Auto Scaling group, for example average over 70 percent for 5 minutes.
  - `<prefix>-unhealthy`: at least one target that the load balancer does not count as healthy.

  See [Using Amazon CloudWatch alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html).
- The AWS CLI on your computer, signed in, or CloudShell. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your alarms or topic have other names, use those names instead, and change the settings at the top of both scripts.

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Create a composite alarm in the console

In the console, the rule is almost written by itself.

1. Open CloudWatch, check the region, and choose **Alarms** in the menu on the left.
2. Tick the boxes in front of `<prefix>-cpu-high` and `<prefix>-unhealthy`. The combination means high CPU and at the same time at least one server that the load balancer does not count as healthy.
3. Click **Create composite alarm**. The first step, **Specify composite alarm conditions**, opens with **Alarms** selected under **Data source**. Under **Conditions**, the console has already written a rule with the selected alarms in a text editor, on two lines, both within `ALARM` and joined with `OR`. Change `OR` at the end of line 1 to `AND`, otherwise it goes off when either of them goes off, and then nothing is gained.
4. Click **Next**. **Configure actions** looks as for an ordinary alarm: **Alarm state trigger** is already **In alarm**, and **Select an existing SNS topic** is selected. Choose `<prefix>-alarms` in the box **Send a notification to...**. Leave **Select suppressor alarm** under **Manage alarm actions** empty.
5. Click **Next**. Under **Add alarm details**, give the alarm the name `<prefix>-cpu-and-unhealthy`, and a description that says where to look, for example `High CPU and an unhealthy server at the same time. Check the Auto Scaling group's activity and the target group's targets.`
6. Click **Next**. **Preview and create** shows the rule, the action and the name. Click **Create composite alarm**. The alarm shows in the list and is `OK` directly, with the condition **All of the alarms go in Alarm**.

### 2. The same thing with the AWS CLI

Now create a second composite alarm, this time for the site check and CPU. The whole script is in [create-composite-alarm.sh](create-composite-alarm.sh):

```
bash create-composite-alarm.sh
```

- **The script fetches the account's id** with `aws sts get-caller-identity` and builds the topic's ARN, `arn:aws:sns:<region>:<account-id>:<prefix>-alarms`, in the variable `TOPIC`.
- **The rule contains double quotes around the alarm names,** which gets hard to read on one line. So the script puts each part in a variable of its own: `A` is `ALARM` with `<prefix>-site-check`, and `B` is `ALARM` with `<prefix>-cpu-high`.
- **The command is `aws cloudwatch put-composite-alarm`.** The same command creates and changes, so if you run it again with the same name, the alarm is overwritten.
- **`--alarm-name`** is `<prefix>-site-and-cpu`. **`--alarm-rule`** is the rule in double quotes, `"$A AND $B"`, which the shell puts together into the whole rule before the command runs. **`--alarm-actions`** is the topic's ARN.
- **The command answers with nothing when it succeeds.** Check in the console that the alarm exists.

### 3. Test with set-alarm-state

Test the rule without putting load on the server or stopping the site, by setting the alarms by hand with `set-alarm-state`, as in [guide 28](../28-alarm-as-sms-via-sns/). The commands are in [test-composite-alarm.sh](test-composite-alarm.sh):

```
bash test-composite-alarm.sh
```

1. **The script first sets `<prefix>-cpu-high` to `ALARM`:**

   ```
   aws cloudwatch set-alarm-state --alarm-name ${PREFIX}-cpu-high --state-value ALARM --state-reason "Test composite"
   ```

   `<prefix>-site-and-cpu` does not change, since only one half of the rule is met. But `<prefix>-cpu-high` sends its ordinary notification, since that alarm still has an action of its own.

2. **Then it sets `<prefix>-site-check` to `ALARM`,** directly after. An alarm set with `set-alarm-state` goes back to its real state the next time CloudWatch evaluates it. When this guide was tested, the site check alarm was in `ALARM` for only 9 seconds. Now both conditions are met, and the composite alarm goes to `ALARM`, in the test at the same moment as the second alarm, and sends a notification to `<prefix>-alarms`. It went back to `OK` just as quickly.

   Three `ALARM` notifications arrive directly: one from each single alarm and one from the composite alarm. If a single alarm also has an OK notification, it sends that when it goes back, in the test after 36 and 68 seconds.
3. **It reads the state directly with `describe-alarms`,** with no pause:

   ```
   aws cloudwatch describe-alarms --alarm-names ${PREFIX}-site-and-cpu --alarm-types CompositeAlarm --query 'CompositeAlarms[0].StateValue' --output text
   ```

   Do not forget `--alarm-types CompositeAlarm`. Without it, `describe-alarms` only returns metric alarms, and then it looks as if the alarm does not exist.

4. **Last, it shows the composite alarm's history.** Since the alarms go back so quickly, the history is the reliable proof that the composite alarm went to `ALARM`, even if it is back in `OK`:

   ```
   aws cloudwatch describe-alarm-history --alarm-name ${PREFIX}-site-and-cpu --alarm-types CompositeAlarm --history-item-type StateUpdate --max-items 4 --query 'AlarmHistoryItems[].[Timestamp,HistorySummary]' --output table
   ```

   `--alarm-types CompositeAlarm` is needed here too. Without it, the history of a composite alarm is empty.

## Check the result

- After the first `set-alarm-state`, the composite alarm is unchanged.
- After the second, it is `ALARM`, and a notification from `<prefix>-site-and-cpu` arrives.
- The history shows `Alarm updated from OK to ALARM`, and soon after `Alarm updated from ALARM to OK`.
- The same shows in the console under **Alarms**, but the command is quicker to repeat.

## Clean up

Delete both composite alarms when you are done, so that they do not cost anything. The single alarms are not affected. One call to `delete-alarms` may delete at most one composite alarm, so delete them one at a time:

```
aws cloudwatch delete-alarms --alarm-names ${PREFIX}-site-and-cpu
```

```
aws cloudwatch delete-alarms --alarm-names ${PREFIX}-cpu-and-unhealthy
```

See [DeleteAlarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/API_DeleteAlarms.html).

## One alarm or several

| Single alarms | Composite alarm |
|---|---|
| You see everything that happens. Each alarm sends its notification, and nothing is missed. The drawback is many notifications, and that you finally stop reading them. | Fewer notifications, since it only goes off when the rule is met. A notification means that something is really wrong. The risk is that a real error only shows in one of the alarms, see below. |

- **Think the rule through carefully,** and ask which errors it does not catch. If the site is down because the database has stopped, CPU on the web servers may be low, and then a rule with `AND` never goes off.
- **Cost:** composite alarms and ordinary alarms are billed per alarm and month. See [Amazon CloudWatch Pricing](https://aws.amazon.com/cloudwatch/pricing/).
- **In operation, you often keep the single alarms but without notifications,** and only the composite alarm sends. This guide does not do that: the single alarms keep their actions.

## Good to know

- **The alarm names in the rule must match exactly,** with dashes and lower case. A misspelled name makes the rule point at an alarm that does not exist, and then it does not work as intended.
- **Quotes are the most common error in the AWS CLI.** If you use double quotes around the names, the shell must get the rule in single quotes, or through variables as in the script. If you mix them up, the double quotes disappear before AWS sees the rule.
- **If you forget to change `OR` to `AND` in the console,** the composite alarm works as a collection alarm. It goes off when any of the alarms goes off, and you get as many notifications as before, plus one.
- **There is also a function called actions suppression.** With it, an alarm can silence the actions of a composite alarm, for example during planned maintenance. In the console it is **Select suppressor alarm** under **Manage alarm actions**, in the step **Configure actions**. This guide does not use it.
- **Alarm mute rules silence the actions of up to 100 alarms during a time window,** once or recurring. The alarms are still evaluated, only the actions are muted. They are on the tab **Mute rules** next to **Alarms**. See [Alarm Mute Rules](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarm-mute-rules.html).
- **Do not remove the notifications from the single alarms before the rule is tested.** If you do, and the rule is wrong, you get no alarms at all.

## Common errors

| Symptom | Cause |
|---|---|
| `describe-alarms` or `describe-alarm-history` shows nothing | `--alarm-types CompositeAlarm` is missing. Without it, only metric alarms are returned. |
| `ValidationError` from `delete-alarms`: only one composite alarm delete is allowed in single request | Two composite alarms in the same call. Nothing is deleted. Delete them one at a time. |
| The script reads `OK` after the second `set-alarm-state` | The alarms went back before the state was read. Check the history: it shows whether the composite alarm went to `ALARM`. |
| The composite alarm never goes to `ALARM` | A name in the rule is misspelled, or the two alarms were not in `ALARM` at the same time. Run the two `set-alarm-state` quickly after each other. |
| As many notifications as before | The rule uses `OR` instead of `AND`. |

## Files

| File | What it is |
|---|---|
| `create-composite-alarm.sh` | Creates the composite alarm `<prefix>-site-and-cpu` with the rule site check `AND` CPU, sending to the topic. |
| `test-composite-alarm.sh` | Sets the two alarms to `ALARM` one after the other, shows the composite alarm's state after each, and its history. The clean-up commands are at the end. |
