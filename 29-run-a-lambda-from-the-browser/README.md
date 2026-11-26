# 29 Run a Lambda from the browser

## What it is

A function URL gives a Lambda function a web address of its own. A function that normally runs on a schedule can then be run directly, for example after a change, by opening the address in the browser. You create a function URL in the console, call it from the browser and the terminal, look at the resource-based policy that is created, and remove the address again. You also see why an open address is a risk.

## Why and when to use it

- **A function that runs on a schedule,** for example every five minutes with Amazon EventBridge, does exactly what you want in operation. But the schedule does not always suit you when troubleshooting.
- **Say that you have just restarted the web servers** or changed something in the load balancer. Then you want to know directly whether the site answers, not wait up to five minutes for the next run.
- **A function URL is an https address of its own that AWS gives the function.** Opening the address runs the function, roughly as if the schedule had started it.
- **There is a larger service for this, Amazon API Gateway,** with many more settings. To just start a function from the browser, a function URL is enough, and it is created with a few clicks.
- **But an address that anyone can open is also a risk.** See the comparison below, and remove the address when you are done.

## How it works

There are three things to keep apart: the address, the auth type and the resource-based policy.

- **Each function can get an address of its own.** It belongs to the function until you remove it, and it has the form:

  ```
  https://<url-id>.lambda-url.<region>.on.aws
  ```

  The id is random and cannot be chosen.
- **The auth type decides who may call it.**
  - With **AWS_IAM**, the call must be signed with keys from a user or role that has the right, just as when the AWS CLI calls AWS. An ordinary browser cannot do that.
  - With **NONE**, no authentication is made at all. Anyone who has the address can run the function, from any computer. It is easy to show, and that is exactly why it is dangerous.
- **For NONE, the function's resource-based policy must say that everyone may call it,** with `Principal` `*`. Since October 2025, new function URLs need two permissions in the policy: `lambda:InvokeFunctionUrl`, and `lambda:InvokeFunction` with a condition that the call comes through the address. The console adds both when you choose NONE.

See [Control access to Lambda function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html).

## Prerequisites

- A Lambda function, named for example `<prefix>-site-check`, such as the site check in [guide 31](../31-site-check-with-lambda/). Any function works. If it runs on a schedule, the schedule is not affected by this guide.
- The AWS CLI on your computer, signed in, or CloudShell. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your function has another name, use that name instead of `<prefix>-site-check`, and change `FN` at the top of `call-function-url.sh`.

| Placeholder | What it is | Example |
|---|---|---|
| `<function-url>` | The function URL, shown in the console after step 1 | `https://abcdefghij1234567890klmnop.lambda-url.eu-north-1.on.aws/` |
| `<sid>` | The id (`Sid`) of a statement in the resource-based policy, from `get-policy` | As shown in the output of `get-policy` |

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Create the address in the console

Create the address in the console, since then you get the resource-based policy as well.

1. Open Lambda in the console, check the region, go to the list **Event Functions** and click on `<prefix>-site-check`.
2. Click the tab **Configuration**. Inside the tab there is a menu on the left, and there you choose **Function URL**. It says **No Function URL**, since the function has no address yet.
3. Click **Edit**. The form **Configure Function URL** opens, with **AWS_IAM** selected as **Auth type**.
4. Choose **NONE** as **Auth type**. Do this only to be able to show the call from an ordinary browser. In real operation you would choose **AWS_IAM**, see the comparison below. When you choose NONE, the console says that Lambda creates a resource-based policy that makes the function public. Expand **View policy statement** to see the two statements before you save.
5. Click **Save**. The address is now shown under **Function URL**. Right after saving, a note may say that the function is missing permissions for public access. Reload the page: the note then says that the function URL is public. Copy the address.

### 2. Call the function

1. Paste the address in the browser and press Enter. The function runs, and the browser shows what the function returns. For the site check from guide 31 it is a small JSON answer, for example `{"ms": 34, "ok": 1}`. One visit in a browser can run the function twice: browsers also ask for an icon, `/favicon.ico`, and that request also reaches the address and runs the function.
2. Fetch the same address with the AWS CLI. That is practical in a script, so that the address does not need to be copied by hand:

   ```
   aws lambda get-function-url-config --function-name ${PREFIX}-site-check --query FunctionUrl --output text
   ```

   It reads the settings for the function's address, among them the address itself and its auth type. `--query FunctionUrl` and `--output text` print only the address, without quotation marks. If the function has no address, you get an error that the resource does not exist.

3. [call-function-url.sh](call-function-url.sh) saves the address in a variable, calls it with `curl` and shows the resource-based policy:

   ```
   bash call-function-url.sh
   ```

### 3. Read the resource-based policy

The console has added statements to the function's resource-based policy, and you can read them with the AWS CLI:

```
aws lambda get-policy --function-name ${PREFIX}-site-check
```

The answer is a JSON document where the policy itself is a long text string. It should contain two statements with `Principal` `*`: one for `lambda:InvokeFunctionUrl`, and one for `lambda:InvokeFunction` with the condition that the call comes through the address. The statement for the schedule from guide 31 shows there too. The two new statements always have the ids `FunctionURLAllowPublicAccess` and `FunctionURLAllowInvokeAction`.

## Check the result

- The browser and `curl` show what the function returns.
- The function does not know whether it was started by the schedule or through the address: it runs the same code. Every call is an ordinary run of the function and shows in its logs and metrics.
- `get-policy` shows the two statements with `Principal` `*`.

## Clean up

Remove the address when you are done:

- In the console: the tab **Configuration**, **Function URL** in the menu on the left, **Delete**, type `confirm` in the field and click **Delete**. The console also removes the two statements for public access from the resource-based policy.
- With the AWS CLI:

  ```
  aws lambda delete-function-url-config --function-name ${PREFIX}-site-check
  ```

If you removed the address with the AWS CLI, check the policy with `get-policy`. If the two statements are still there, remove them:

```
aws lambda remove-permission --function-name ${PREFIX}-site-check --statement-id FunctionURLAllowPublicAccess
```

```
aws lambda remove-permission --function-name ${PREFIX}-site-check --statement-id FunctionURLAllowInvokeAction
```

## NONE compared with AWS_IAM

| NONE | AWS_IAM |
|---|---|
| Simple: the address is enough, and you can show the function to anyone by sending the link. | Only those who have an IAM identity with the right permission and sign the call. It stops anonymous calls completely. |
| Whoever finds the address can call the function as often as they want, for example in a loop. Every call runs the function, and many calls become traffic and costs that nobody counted on. | An ordinary browser is not enough. |

- **Reserved concurrency limits the damage.** It sets a ceiling for how many runs of the function may be in progress at the same time, so that a loop cannot start any number.
- **Reserved concurrency set to 0 throttles all requests to the function URL,** which then answer with HTTP `429`. It is an emergency brake, but note that it also stops the scheduled runs.
- **In real operation, use AWS_IAM,** or give the function no address at all and run it with `aws lambda invoke` when needed. NONE is only for showing, and that is why you remove the address directly afterwards.

## Good to know

- **If you create the address with `aws lambda create-function-url-config` and `--auth-type NONE`,** you must add the resource-based policy yourself with `aws lambda add-permission`, otherwise the calls through the address are denied with `403`. That is why this guide uses the console.
- **The address works like a key when the auth type is NONE.** Do not put it in a repository, a README or a chat. If it has spread, the simplest thing is to remove the address and create a new one: it gets a new id.
- **Every call through the address counts as an ordinary run** of the function, and costs like one.
- **The address does not affect a schedule.** The function keeps running on its schedule as before, both while the address exists and after you have removed it.

## Common errors

| Symptom | Cause |
|---|---|
| `403 Forbidden` when calling the address | The resource-based policy lacks one of the two statements, typically when the address was created with the AWS CLI. |
| An error that the resource does not exist from `get-function-url-config` | The function has no address, or `FN` is wrong. |
| `429` when calling the address | The function's reserved concurrency is 0. |

## Files

| File | What it is |
|---|---|
| `call-function-url.sh` | Reads the function URL, calls it with `curl` and shows the resource-based policy. The clean-up steps are at the end. |
