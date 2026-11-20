# 08 Credential report

## What it is

A credential report is a report that IAM produces for all users in the account. It shows at once who has MFA, who has access keys and when they were last used. You produce it in the console and with a command in CloudShell, and go through the columns that matter.

## Why and when to use it

- **It gives an overview quickly.** The report collects all users in the account in one table, one row per user, also the root user.
- **It answers two of the most important security questions directly:** does everyone who signs in have MFA, and are there access keys that nobody uses any more?
- **It also shows when the password was last used.** A user that has not signed in for months may no longer be needed.
- **You produce it with one click in the console or one command in CloudShell.** In an organisation with many users, it is the only reasonable way to get an overview.
- **It is good evidence in documentation.** You can show that you have checked the account's security, and what you did about what you found.

## How it works

- IAM builds the report when you ask for it, with the information that exists about each user at that moment.
- According to AWS's documentation, a new report can be produced at most once every four hours. It applies to the whole account, not per person.
- If you ask for a new one within four hours, you get the latest one instead. If you have just turned on MFA, it does not show until later.
- The report is a CSV file, text with commas between the columns. It opens directly in a spreadsheet program, where you can sort and filter.
- Every user gets a row. The root user is also included, on a row called `<root_account>`, so you see for example that it has MFA and no access keys.

## Prerequisites

- A user in the console that may produce the credential report, for example an administrator. See [Generate credential reports for your AWS account](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_getting-report.html).
- For the command: CloudShell. See [Getting started with AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/getting-started.html).

IAM is global in the account, so you do not need to choose a region.

## Step by step

### 1. In the console

1. Open IAM and choose **Credential report** in the menu on the left. It is under **Access reports**.
2. Click **Download Report**. The file ends up in your downloads folder.
3. Open the file in a spreadsheet program. Every column has its own column, and you can select the header row and turn on filtering.
4. Look at `mfa_active`, which is `true` or `false`, in lower case, and `password_last_used`, which shows the latest sign-in to the console.
5. Look at `access_key_1_active` and `access_key_1_last_used_date`. They show whether the user has an active access key and when it was last used.

### 2. With a command

[save-credential-report.sh](save-credential-report.sh) does all the steps below in one go. Upload it to CloudShell, or type the commands one at a time.

1. Ask IAM to build the report. The answer says `STARTED` the first time and `COMPLETE` when it is ready. The command needs no parameters. If a report has been produced in the last four hours, nothing new happens, and the old one is used.

   ```
   aws iam generate-credential-report
   ```

2. Fetch the report and save it as CSV. The content is in the field `Content`, and it is sent encoded in base64, a way to send a file as text. Therefore it is passed to `base64 -d`, which decodes it. Without that step, the file is one long line of unreadable characters.

   ```
   aws iam get-credential-report --query Content --output text | base64 -d > credential-report.csv
   ```

3. The whole report is wide. `cut` picks out some columns, with comma as the separator. Column 1 is the user name, 4 is whether a password exists, 5 is the latest sign-in, 8 is `mfa_active` and 9 is `access_key_1_active`.

   ```
   cut -d, -f1,4,5,8,9 credential-report.csv
   ```

If you want the file on your computer, download it with **Actions, Download file** in CloudShell, opened in a tab of its own.

If you run the commands in Git Bash on Windows instead of CloudShell, the line `base64: invalid input` may show up. When this was tested, the file was still complete, so check it with `head` before you redo anything.

## Check the result

The columns that matter. The values are written in lower case, `true` and `false`.

| Column and value | What it means |
|---|---|
| `mfa_active` `false` | The user has no MFA. For a user that signs in to the console, it is the first thing to fix. |
| `password_last_used` | The latest sign-in to the console. `no_information` means that the password has not been used, or that information is missing. |
| `access_key_1_active` `true` | The user has an active access key. Consider whether it is needed. |
| `access_key_1_last_used_date` | When the key was last used. An active key that has never been used is an unnecessary risk and can be deactivated. |
| `N/A` in the password columns | The user has no password at all. That applies to users that only use the CLI, and for them the console columns are not relevant. |

**What to look for:**

- The root user (`<root_account>`) and administrator users should have `mfa_active` `true`. If it says `false`, something has gone wrong and should be fixed directly.
- Users that sign in to the console should have MFA. A policy can require it, see [guide 09](../09-require-mfa-in-a-policy/).
- Nobody should have access keys that are never used.
- The fixes are simple: turn on MFA for users that sign in to the console, and deactivate or remove keys that are not used. Then produce the report again when four hours have passed, and compare. Two reports, before and after, are good evidence in documentation.

## Clean up

The report contains no passwords or keys, but it shows which users lack MFA. Remove the file from CloudShell when you no longer need it:

```
rm credential-report.csv
```

Do the same with the file you downloaded to your computer, unless you keep it somewhere that only you can reach.

## Good to know

- **A new report can be produced at most every four hours.** If you change something and want to see the result, wait, or check the user directly in IAM.
- **Without `base64 -d`, the file is unreadable.** If you open it in an editor and it looks like one long line of random characters, that is what has happened.
- **The report includes the first two access keys per user.** If a user has more, it shows in the column `additional_credentials_info`, and then you look at the user directly.
- **Do not put the report in a public repository.** It shows which users lack MFA. Describe the result in your documentation instead.

## Common errors

| Symptom | Cause |
|---|---|
| A change you just made does not show | The report is at most four hours old, and a new one has not been produced yet. |
| The CSV file is one long line of random characters | `base64 -d` is missing. |
| `base64: invalid input` in Git Bash | Check the file with `head` before you redo anything. It was complete when tested. |

## Files

| File | What it is |
|---|---|
| `save-credential-report.sh` | Produces the credential report, saves it as `credential-report.csv` and shows the most important columns. Run it in CloudShell. |
