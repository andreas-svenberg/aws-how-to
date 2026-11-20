# 11 Profiles in the AWS CLI

## What it is

With a profile in the AWS CLI, you can have several identities signed in in the same terminal and choose which one each command uses. You sign in as a test user in a profile of its own, test what the user may and may not do, and look at the file where the profiles are saved.

## Why and when to use it

- Your terminal is signed in as your administrator user. It may do everything, so everything works.
- But how do you test that a test user may only read in S3, as its policy says? The IAM policy simulator is one way. Actually running the commands as the test user is another.
- With profiles, you can be signed in as both the administrator and the test user at the same time. Each sign-in is saved in a profile of its own, and you choose the profile with the flag `--profile`.
- You do not need to sign out and in again back and forth, and the risk of forgetting who you are signed in as is smaller.
- The same technique is used when you have several AWS accounts, for example one for test and one for production. One profile per account.

## How it works

- If no profile is given, the AWS CLI uses the profile `default`. It is the one created when you ran `aws login` the first time.
- `aws login --profile <name>` creates a new profile with that name, or signs in again in one that already exists.
- The profiles are saved in the file `config` in the folder `.aws` in your home folder. The temporary keys are saved separately in a cache, according to AWS's documentation in the folder `.aws/login/cache`.
- The flag `--profile` after a command makes just that command run with that profile. Without the flag, `default` is used again.
- To use the same profile for many commands, set the environment variable `AWS_PROFILE`. It then applies until you close the terminal or remove the variable.

## Prerequisites

- AWS CLI version 2.32.0 or later on your computer. Check with `aws --version`. See [Login for AWS local development using console credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html).
- Your own user signed in with `aws login` in the profile `default`.
- A test user with console access, in a group.
- The AWS managed policy `SignInLocalDevelopmentAccess` attached to the test user's group, see step 1.

| Placeholder | What it is | Example |
|---|---|---|
| `<test-user>` | The test user's name, also used as the profile's name | `test-user` |
| `<group-name>` | The group the test user is in (IAM, User groups) | `developers` |
| `<region>` | The region you work in | `eu-north-1` |

## Step by step

### 1. Let the test user sign in from the CLI

- According to AWS's documentation, `aws login` requires that the user may sign in from a local development environment. The root user needs nothing extra, but ordinary IAM users do.
- AWS has a ready-made policy for it called `SignInLocalDevelopmentAccess`. It only gives the right to sign in from the CLI, no permissions in the services.
- An administrator user with `AdministratorAccess` may do everything, and therefore `aws login` works for it from the start.

1. In IAM, choose **User groups** and click `<group-name>`. Tab **Permissions**.
2. **Add permissions**, **Attach policies**.
3. Search for `SignInLocalDevelopmentAccess`, tick it and click **Attach policies**.

### 2. Sign in as the test user in a profile of its own

1. In the terminal, run `aws login` with the profile `<test-user>`. The profile does not exist yet, so it is created. The profile has no region, so the command first asks for **AWS Region**. Type `<region>`. If you only press Enter, it becomes `us-east-1`, and then you end up in the wrong region.

   ```
   aws login --profile <test-user> --remote
   ```

   The flag `--remote` makes the command print a link instead of opening the browser itself. That is practical here, since the browser is already signed in as administrator.

2. Copy the link and open it in a private window. Then you can sign in as another user without the administrator being signed out.
3. Sign in as `<test-user>`. After the sign-in, a code is shown. Copy it and paste it into the terminal, where the command is waiting. If the AWS CLI then asks whether you want to configure AWS skills and an MCP server for AI agents, it is not part of this guide, so answer `n`.
4. Check that it went right. The `Arn` should end with `user/<test-user>`.

   ```
   aws sts get-caller-identity --profile <test-user>
   ```

5. Run the same command without a profile. Then your administrator user is shown, since `default` has not changed. Two identities in the same terminal.

   ```
   aws sts get-caller-identity
   ```

### 3. Test the permissions

The examples assume that the test user's group has `AmazonS3ReadOnlyAccess` and nothing in EC2.

1. S3 works, the test user may read. The command gives the same list as when the administrator runs it, but it is the test user's permissions that decide.

   ```
   aws s3 ls --profile <test-user>
   ```

2. EC2 is denied, it is not part of the policy. The command answers with an error that the action is not allowed, `UnauthorizedOperation`. Just as it should be according to least privilege.

   ```
   aws ec2 describe-instances --profile <test-user>
   ```

3. To run many commands as the test user, set `AWS_PROFILE`. Then all commands in the terminal run as the test user, until further notice.

   ```
   export AWS_PROFILE=<test-user>
   ```

   In PowerShell:

   ```
   $env:AWS_PROFILE = "<test-user>"
   ```

4. Remove the variable to go back to `default`, your administrator user. Always check with `aws sts get-caller-identity`.

   ```
   unset AWS_PROFILE
   ```

   In PowerShell:

   ```
   Remove-Item Env:AWS_PROFILE
   ```

### 4. Look at the file `.aws/config`

```
cat ~/.aws/config
```

On Windows, it is the folder `.aws` under your user folder. It looks roughly like this:

```
[default]
login_session = arn:aws:iam::<account-id>:user/<your-user>

[profile <test-user>]
login_session = arn:aws:iam::<account-id>:user/<test-user>
region = <region>
```

- The profile `default` has no extra word, only the name in square brackets. It is the one used when you give no profile.
- The line `login_session` shows who the profile signed in as, with the user's ARN. The line `region` is there if you gave a region when you signed in.
- Other profiles have the word `profile` before the name, in square brackets. That is how the AWS CLI tells them apart in the file `config`.
- There are no keys in the file. The temporary keys are in the cache and are replaced automatically, which is why `aws login` is safer than access keys in the file `credentials`.

## Check the result

- `aws sts get-caller-identity --profile <test-user>` shows the test user's ARN.
- `aws sts get-caller-identity` without a profile shows your administrator user.
- Commands with `--profile <test-user>` are allowed or denied according to the test user's policies.

## Clean up

Sign out the profile when you are done. The saved keys are then removed.

```
aws logout --profile <test-user>
```

The answer also says that programs that have already read the keys can keep using them until they expire, and that they are valid for 15 minutes.

If the test user does not need to sign in from the CLI any more, detach `SignInLocalDevelopmentAccess` from the group: the group, **Permissions**, select the policy and **Remove**.

## Common errors

| Symptom | Cause |
|---|---|
| Everything works for the test user | You forgot `--profile`. Then the command runs as `default`, your administrator user, and the test says nothing about the test user. Make it a habit to run `aws sts get-caller-identity` when you are unsure. |
| The profile ends up in `us-east-1` | You pressed Enter when `aws login` asked for the region. |
| `aws login` is denied for the test user | `SignInLocalDevelopmentAccess` is not attached to the user's group. |
| *Your session has expired* | According to AWS's documentation, the keys are renewed automatically, but the session is valid for at most 12 hours. Run `aws login --profile <test-user>` again. You do not need to think about the region, it was saved in the profile the first time. |
| `aws login` does not exist | The AWS CLI is older than version 2.32.0. |

## Files

This guide has no files.
