# 31 Site check with Lambda

## What it is

A small Lambda function in Python asks a website for a page, just like a visitor, and measures how long it takes. It sends the result to CloudWatch as two metrics of its own: whether the site was available, 1 or 0, and the response time in milliseconds. A schedule in EventBridge runs the function every five minutes, and an alarm goes off if the site has not answered twice in a row, or if the check has stopped running.

## Why and when to use it

- **The check sees something that the servers do not see themselves:** whether the whole site answers from the outside, through the load balancer and DNS.
- **Metrics from the servers say how each server is doing,** but not whether a visitor can actually reach the site.
- **A small job like this does not need a server.** Lambda runs the code when it is time, and nothing runs in between. There is no server standing and waiting, costing money.
- **The function's role only allows it to write logs and to send metrics to its own namespace.** Nothing else.

## How it works

- **In Lambda, you upload a function,** for example a few lines of Python. There is no server to choose. The function runs when something happens, and between runs nothing runs at all.
- **AWS takes care of everything under the code:** servers, operating system and scaling. Each run may take at most 15 minutes, so Lambda suits short jobs, not a web server that should run all the time.
- **You pay per call and for the time the code runs.** See [AWS Lambda pricing](https://aws.amazon.com/lambda/pricing/).
- **Everything the function prints ends up in CloudWatch Logs,** in a log group named after the function, `/aws/lambda/<function-name>`.
- **Something must start the function.** Here it is a schedule in Amazon EventBridge, `rate(5 minutes)`. The function gets an event, a JSON object that describes what happened, but this function does not need to read it.
- **The metrics end up in a namespace of their own, `SiteCheck`,** next to the namespaces that start with `AWS/`. Everything under `AWS/` comes from AWS. Everything else, someone else has sent.
- **The alarm treats missing data as bad.** If the function stops sending, you know nothing about the site, and that is also something to alarm about.

See [What is AWS Lambda?](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html).

## Prerequisites

- A website that answers on HTTP or HTTPS, for example through an Application Load Balancer.
- An SNS topic for the alarm, named for example `<prefix>-alarms`, with a confirmed e-mail subscription. See [Creating an Amazon SNS topic](https://docs.aws.amazon.com/sns/latest/dg/sns-create-topic.html).
- A user that may create Lambda functions, IAM roles and policies, EventBridge rules and CloudWatch alarms, for example an administrator.

| Placeholder | What it is | Example |
|---|---|---|
| `<prefix>` | The prefix for your resource names, see the root README | `demo` |
| `<site-url>` | The full address to check. It must answer with status `200` | `http://demo-alb-1234567890.eu-north-1.elb.amazonaws.com/` |
| `<site-name>` | A short name for the site, shown as the dimension `Site` | `demo` |

## Step by step

### 1. Create the function

1. Open Lambda in the console, check the region at the top right, and click the button **Create an Event Function**, not the arrow next to it. **Author from scratch** is selected, since you have your own code.
2. Name it `<prefix>-site-check` and choose **Python 3.12** as **Runtime**, the language the code is written in. The architecture can stay as it is: for such a small function, the choice does not matter.
3. Leave **Permissions** as they are: Lambda creates a new role that may write to CloudWatch Logs, nothing more. Click **Create Event Function**.
4. Under the tab **Code**, replace the example code in `lambda_function.py` with the content of [site-check.py](site-check.py), and click **Deploy**. Changes do not run until they are deployed.
5. The default time for a run is 3 seconds. The function waits up to 10 seconds for the site, so set the timeout to 20 seconds under **Configuration** and **General configuration**.
6. Under **Configuration** and **Environment variables**, add `SITE_URL` with `<site-url>`, and `SITE_NAME` with `<site-name>`. The code reads them: nothing is hard-coded. The page in `SITE_URL` must answer with status `200`, since the code counts every other answer as unavailable. If the site is WordPress and you want to check the login page, use `http://<alb-dns>/wp-login.php`.

### 2. Permission and test

1. Under **Configuration** and **Permissions**, the role's name is shown as a link. It opens the role in IAM.
2. Choose **Add permissions** and **Create inline policy**, and switch from the visual editor to **JSON**. Paste the content of [site-check-policy.json](site-check-policy.json). Give the policy a name and create it.

   The policy allows `cloudwatch:PutMetricData`, with a condition that the namespace must be `SiteCheck`. The least possible permission.

3. Back in the function, choose the tab **Test**, create a test event with the default content and click **Test**. The response should contain `"ok": 1` and the response time. If it says 0, read the output: most often `SITE_URL` is wrong.
4. Under **Monitor** and **View CloudWatch logs**, you find the log group `/aws/lambda/<prefix>-site-check`. Set a retention period on it, so that the logs do not stay forever.

### 3. The schedule

1. In the function's overview, click **Add trigger** and choose **EventBridge**, which in the console may still be called **CloudWatch Events**.
2. Create a new rule named `<prefix>-site-check-schedule`. The rule is a resource of its own in EventBridge and stays if the function is deleted, so it must be cleaned up too.
3. Choose the rule type schedule expression, with the expression `rate(5 minutes)`, and click **Add**. Now the function runs every five minutes, without any server.

### 4. The alarm

After the first runs, the namespace `SiteCheck` is under **Classic metrics** in CloudWatch, with `Available` and `ResponseTimeMs` per `Site`. It can take up to 15 minutes before a new metric appears in the list.

1. Create an alarm on `Available` with the statistic **Minimum** and the period **5 minutes**.
2. Set the condition to lower than `1`, with **2 out of 2** data points.
3. Under **Missing data treatment**, choose to treat missing data as bad (breaching the threshold). Then you find out if the function has stopped running.
4. Send the notification to `<prefix>-alarms`, and name the alarm `<prefix>-site-check`.

## Check the result

- The test in step 2 answers `"ok": 1` and a response time.
- Within 15 minutes or so, `Available` and `ResponseTimeMs` show under `SiteCheck` in CloudWatch, with a new point every five minutes.
- The alarm is `OK` as long as the site answers.

## Clean up

Remove everything the guide created, when you no longer want the check:

1. The alarm `<prefix>-site-check` in CloudWatch.
2. The rule `<prefix>-site-check-schedule` in EventBridge. It stays even if the function is deleted.
3. The function `<prefix>-site-check` in Lambda.
4. The log group `/aws/lambda/<prefix>-site-check` in CloudWatch Logs.
5. The role that Lambda created for the function, in IAM. Its name starts with the function's name. The inline policy disappears with the role.

## Good to know

- **Lambda's default timeout is 3 seconds.** A site that answers slowly then looks like a site that does not answer at all. That is why step 1 sets 20 seconds.
- **Costs:** a function that runs every five minutes costs very little in Lambda, but its metrics, logs and the alarm cost like all others. Set a retention period on the log group. See [Amazon CloudWatch Pricing](https://aws.amazon.com/cloudwatch/pricing/).
- **To run the check directly, without waiting for the schedule,** you can give the function a function URL, see [guide 29](../29-run-a-lambda-from-the-browser/).
- **To keep a history of every check,** with the time and any error message, save each check in a DynamoDB table, see [guide 33](../33-site-check-history-in-dynamodb/).

## Common errors

| Symptom | Cause |
|---|---|
| The test answers `"ok": 0` | `SITE_URL` is wrong, or the site does not answer with status 200. Read the output in the log. |
| The test times out | The timeout is still 3 seconds. Set it to 20 seconds. |
| A permission error for `cloudwatch:PutMetricData` in the test result or the log | The inline policy is missing on the role, or the namespace in the policy is not the same as in the code. |
| No metrics in CloudWatch | The schedule is not created, or the metric is new: it can take up to 15 minutes before it appears in the list. |
| The alarm goes to `ALARM` although the site works | The function has stopped running, for example because the rule was removed, and missing data counts as bad. |

## Files

| File | What it is |
|---|---|
| `site-check.py` | The function's code. Paste it into `lambda_function.py`. |
| `site-check-policy.json` | The inline policy for the function's role: send metrics, only to the namespace `SiteCheck`. |
