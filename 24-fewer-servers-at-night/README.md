# 24 Fewer servers at night

## What it is

A scheduled action changes the size of an Auto Scaling group (min, max and desired capacity) at a set time. With one action in the evening and one in the morning, the group runs fewer servers at night and goes back to its normal size in the morning.

## Why and when to use it

- A group with min 2 runs two servers around the clock, also at three in the morning when nobody visits the site.
- Target tracking scales in when CPU is low, but never below min. With min 2 there are always at least two servers, however low the load is. The policy cannot save anything at night.
- A scheduled action changes min, max and desired at a given time: lower in the evening, higher again in the morning.
- Every server that does not run saves instance hours, and with that money.

Use it when the load follows a known pattern over the day or the week. It is a trade-off between cost and availability, see [Cost against availability](#cost-against-availability).

## How it works

- **Cron with five fields**, always in quotes: minute, hour, day of month, month, day of week. A star means all values.
  - `"0 20 * * *"` means 20:00 every day.
  - `"0 7 * * 1-5"` means 07:00 Monday to Friday, where 1 is Monday and 5 is Friday.
- **Time zone:** without one, the cron expression is read in UTC. With a time zone such as `Europe/Stockholm`, the schedule follows local time, including daylight saving time.
- **Size:** every action must change at least one of min, max and desired. This guide sets all three, so that it is clear what the group should have afterwards.

## Prerequisites

- An Auto Scaling group, named for example `<prefix>-web-asg`. The examples assume min 2, max 4 and desired 2 as the normal size. See [Tutorial: Set up a scaled and load-balanced application](https://docs.aws.amazon.com/autoscaling/ec2/userguide/tutorial-ec2-auto-scaling-load-balancer.html).
- The AWS CLI in a terminal on your computer, or CloudShell.
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your group has another name, use that name instead of `${PREFIX}-web-asg` in the commands and in `schedule.sh`.

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
PREFIX=demo
```

### 1. Check the group's size

Note min, max and desired. That is the group's normal size, which the morning action should set back.

```
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${PREFIX}-web-asg" --query "AutoScalingGroups[0].[MinSize,MaxSize,DesiredCapacity]" --output text
```

### 2. Create a scheduled action in the console

1. EC2, in the menu on the left **Auto Scaling Groups**.
2. Select `<prefix>-web-asg`, tab **Automatic scaling**. Both the scaling policies and the scheduled actions are there.
3. Scroll down to **Scheduled actions**, **Create scheduled action**. The list is empty if you have not created an action before.
4. Name `<prefix>-night`. Set **Desired capacity**, **Min** and **Max** to `1`. The group then has exactly one server after the action.
5. Under **Recurrence**, choose every day at 20:00, as cron `0 20 * * *`. Exactly how the choices look in the list can vary, so look at what the console offers. **Time zone** is `Etc/UTC` by default. Change it to your own time zone, for example `Europe/Stockholm`. Leave **Specific start time** and **Set End Time**, they limit when the schedule applies.
6. Save the action. It shows up in the list under Scheduled actions, with time and size. Nothing happens until the clock reaches 20:00.

### 3. Evening and morning with the AWS CLI

[schedule.sh](schedule.sh) creates two actions and lists them in a table.

1. Open `schedule.sh` and check the two lines at the top: the group name and the time zone. If your group's normal size is not min 2, max 4 and desired 2, change the sizes in the morning action.
2. Run it from the folder where the file is. In CloudShell, upload the file first, it ends up in the home folder.

   ```
   bash schedule.sh
   ```

The core of the script is the evening action:

```
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name "$ASG" \
  --scheduled-action-name "${PREFIX}-night" \
  --recurrence "0 20 * * *" \
  --time-zone "$TIME_ZONE" \
  --min-size 1 --max-size 1 --desired-capacity 1
```

The morning action `<prefix>-morning` has the recurrence `"0 7 * * 1-5"` and sets min 2, max 4 and desired 2.

The evening action has the same name as the one created in the console. That is not an error: AWS overwrites the old one. The same name always overwrites.

### 4. List the actions

The command only reads, so it is safe to run as many times as you like. Without `--auto-scaling-group-name`, the actions for all groups in the region are listed.

```
aws autoscaling describe-scheduled-actions --auto-scaling-group-name "${PREFIX}-web-asg" --output table
```

Check that the time zone is right on both actions, and that the next run looks reasonable.

## Check the result

Look at the group after 20:00, for example the next morning. On the tab **Activity** there should be a row saying that a server was terminated, and the description says why. After 07:00 on a weekday, a new server should have been started.

## Clean up

If you do not want to keep the schedule, remove the actions:

```
aws autoscaling delete-scheduled-action --auto-scaling-group-name "${PREFIX}-web-asg" --scheduled-action-name "${PREFIX}-night"
```

```
aws autoscaling delete-scheduled-action --auto-scaling-group-name "${PREFIX}-web-asg" --scheduled-action-name "${PREFIX}-morning"
```

Removing an action does not change the group's size. If the evening action has already run, check afterwards that the group is back at its normal size:

```
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${PREFIX}-web-asg" --query "AutoScalingGroups[0].[MinSize,MaxSize,DesiredCapacity]" --output text
```

If it is not, set it back to the normal size you noted in step 1:

```
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "${PREFIX}-web-asg" --min-size 2 --max-size 4 --desired-capacity 2
```

If the group was created by a CloudFormation stack, the actions you created here are outside the stack. The stack does not know about them, so remove them when you are done.

## Cost against availability

- At night the group runs one server instead of two: fewer instance hours.
- The scheduled action itself costs nothing. Only the instance hours cost.
- But with one server, the whole site is in one availability zone. If that zone goes down, or the server crashes, the site is down until the group has started a new server. You give up the redundancy over two zones at night.
- With min, max and desired at 0, the servers cost nothing at night, but the site does not answer at all. A load balancer and a database still cost, they are not affected by the schedule.
- The morning action only runs Monday to Friday, while the evening action runs every day. From Friday evening to Monday morning there is one server. Whether that is right depends on how the site is used at weekends.
- There is no right answer. It is a business decision, cost against availability, and it should be a conscious choice. Write down why you chose as you did.

## Common errors

| Symptom | Cause |
|---|---|
| The action runs one or two hours wrong | `--time-zone` is missing, so cron is read in UTC. Check the time zone in the list. |
| The command gets completely wrong values | The cron expression is not in quotes. bash replaces the stars with the file names in the folder. |
| An action changed without warning | An action with the same name overwrites the old one. Dangerous if two people use the same name for different things. |
| The action runs a little late | A scheduled action can run up to two minutes after the given time. |
| The group does not scale out at night although the load rises | After the action, target tracking only works within the new min and max. With max 1 the group cannot scale out. |
| Cannot create more actions | A group can have at most 125 scheduled actions. |

## Files

| File | What it is |
|---|---|
| `schedule.sh` | Creates the evening and the weekday morning action and lists them. The commands for removing them are at the end. |
