# 27 Fixed response from the load balancer

## What it is

An Application Load Balancer usually sends everything on to a target group. But it can also answer by itself, with a fixed response that you write, without asking any server. A good example is a maintenance page. You add a rule for the path `/maintenance` in the console, do the same with the AWS CLI and a JSON file, test with `curl` and remove the rule.

## Why and when to use it

- **The load balancer can answer by itself.** Apart from forwarding to a target group, it can answer directly with a fixed response. You decide the status code, the content type and the text itself.
- **The request never reaches a server.** It does not show in the web server's logs and puts no load on the servers.
- **The classic example is a maintenance page.** When you upgrade the application or the database, you want visitors to get a friendly message instead of an error message.
- **It works even if all servers are gone.** Since no server is needed, the page works even if all servers are stopped or being replaced. That is exactly when a maintenance page is needed.
- **It is a rule on the listener.** You do not touch the servers, the application or the target group.

## How it works

It is the same mechanism that is used to send different paths to different target groups.

- **A listener, for example on HTTP port 80, has a list of rules.** From the start it only has the default rule, which forwards everything to the target group. You can add more rules before it.
- **A rule has conditions.** This guide uses a condition on the path, **Path**, with the value `/maintenance`. A path pattern can be at most 128 characters long, and it is case-sensitive.
- **A rule has an action.** Instead of forwarding to a target group, you choose **Return fixed response**. The fixed response has a status code in the 200, 400 or 500 range, a content type such as `text/html` or `text/plain`, and a text of at most 1024 characters. The text can be empty.
- **Each rule has a priority, a number from 1 to 50000.** The load balancer tries the rules with the lowest number first, and the first one that matches decides.
- **The default rule is always tried last** and takes everything that no other rule matched. That is why the rest of the site works as usual when you add the rule.

See [Add a listener rule for your Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/add-rule.html).

## Prerequisites

- An Application Load Balancer named for example `<prefix>-alb`, with a listener on HTTP port 80 that forwards to a target group with healthy servers.
- The AWS CLI on your computer, signed in, or CloudShell. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your load balancer has another name, use that name instead of `<prefix>-alb`, and change `ALB_NAME` at the top of `add-maintenance-rule.sh`.

| Placeholder | What it is | Example |
|---|---|---|
| `<alb-dns>` | The load balancer's DNS name (EC2, Load Balancers, the load balancer) | `demo-alb-1234567890.eu-north-1.elb.amazonaws.com` |
| `<rule-arn>` | The rule's ARN, printed by the script | `arn:aws:elasticloadbalancing:eu-north-1:123456789012:listener-rule/app/...` |

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Rule in the console

1. Go to EC2 and choose **Load Balancers** in the menu on the left.
2. Select `<prefix>-alb` and choose the tab **Listeners and rules**. There is the listener **HTTP:80**.
3. Click on **HTTP:80** to open the listener. Under the tab **Rules**, you see the default rule that forwards to the target group. Click **Add rule**.
4. Click **Add condition**, choose **Path** and type `/maintenance` as value. Confirm the condition.
5. Under **Routing action**, choose **Return fixed response** instead of forwarding to a target group.
6. Choose **Response code** `503`, **Content type** `text/html` and type a short HTML text in **Response body**, for example:

   ```
   <h1>Maintenance</h1><p>Maintenance in progress, please come back later.</p>
   ```

7. Click **Next** and type `10` as **Priority**. No other rule on the listener may have the same number. Click **Next** again and finally **Create**.
8. Open `http://<alb-dns>/maintenance` in the browser and see the page.
9. Delete the rule before the next step: select it under the tab **Rules** and delete it. Two rules on the same listener cannot have the same priority, and the next step uses 10 again.

### 2. The action in a JSON file

The action is easiest to write in a JSON file, so that you avoid struggling with quotation marks in the command. Open [maintenance-response.json](maintenance-response.json) in a text editor:

- **`Type` is `fixed-response`.** That is the CLI name for what is called **Return fixed response** in the console.
- **Under `FixedResponseConfig`, `StatusCode` is `503` and `ContentType` is `text/html`.** Note that the status code is in quotation marks, as a text.
- **`MessageBody` is the HTML text itself.**

### 3. Create the rule with the AWS CLI

Run [add-maintenance-rule.sh](add-maintenance-rule.sh) in the same folder as the JSON file:

```
bash add-maintenance-rule.sh
```

The script first fetches the ARN of `<prefix>-alb` and of its listener on port 80, with `describe-load-balancers` and `describe-listeners`. The rule itself is created with this command:

```
aws elbv2 create-rule --listener-arn <listener-arn> --priority 10 --conditions Field=path-pattern,Values=/maintenance --actions file://maintenance-response.json
```

- **`--listener-arn` is the ARN of the listener on HTTP:80,** and `--priority 10` is the priority. No other rule on the listener may have the same number.
- **`--conditions` gives the condition,** that is when the rule applies. `Field` is `path-pattern` and `Values` is `/maintenance`. It corresponds to **Path** in the console.
- **In Git Bash, a value starting with a slash can be turned into a Windows path,** so the script sets `MSYS_NO_PATHCONV=1` first.
- **`--actions` points at the JSON file** with `file://`.

The script prints the rule's ARN and then tests the address with `curl`.

## Check the result

```
curl -i http://<alb-dns>/maintenance
```

- **`-i` makes `curl` show the response's headers,** not just the content. The first line is the status line, and there it says `503`. After the headers comes your HTML. In the browser, the same address looks like a simple page.
- **The start page and all other addresses answer as usual,** since they do not match the condition. They fall through to the default rule and are forwarded to the target group. The script shows the start page's status code last.
- **The load balancer's health check is not affected by the rule.** It goes directly to the servers in the target group, not through the listener's rules. The servers stay healthy.

## Clean up

Remove the rule, so that the listener only has the default rule again. In the console, select the rule under the tab **Rules** and delete it. With the AWS CLI, use the rule's ARN that the script printed:

```
aws elbv2 delete-rule --rule-arn <rule-arn>
```

Test afterwards with `curl -i` that `/maintenance` is now forwarded to the servers, which probably answer that the page does not exist, instead of `503`.

## Good to know

- **To show the page for all visitors during planned maintenance,** you can change the default rule, or add a rule with the condition **Path** `/*`, which matches everything, and a priority with a low number so that it is tried first. That is not tested in this guide, so test it yourself before you rely on it.
- **The status code 503 means that the service is temporarily unavailable.** It is better than 200 for a maintenance page, since search engines then understand that the page will come back, and do not replace the site's content with the maintenance text.
- **The lowest number is tried first.** It is easy to think the other way round and believe that a high priority means that the rule is most important. Priority 1 wins over priority 10.
- **The text in the fixed response may be at most 1024 characters.** A whole maintenance page with images and styles does not fit. Keep it short.
- **Characters outside English, such as å, ä and ö, can be written as HTML codes** (for example `&aring;` for å), so that they show correctly whatever character encoding the browser assumes for the fixed response.

## Common errors

| Symptom | Cause |
|---|---|
| An error about the priority when the rule is created | There is already a rule with the same number, for example the one from the console in step 1. Delete it or choose another priority. |
| The rule never matches when created in Git Bash | `/maintenance` was turned into a Windows path. Set `MSYS_NO_PATHCONV=1`, or run in CloudShell. The script does it. |
| *No HTTP:80 listener found* | The load balancer has no listener on port 80, or `ALB_NAME` is wrong. |
| Strange characters instead of å, ä or ö | Write them as HTML codes, see Good to know. |

## Files

| File | What it is |
|---|---|
| `maintenance-response.json` | The action: fixed response with 503, `text/html` and a short HTML text. |
| `add-maintenance-rule.sh` | Finds the listener on port 80, creates the rule with priority 10, tests with `curl` and prints the command to remove the rule. |
