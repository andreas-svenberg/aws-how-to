# 09 Require MFA in a policy

## What it is

A policy that makes MFA a rule that IAM checks, not just a recommendation. You use a ready-made example policy from AWS's documentation, attach it to a group, and test as a user in the group, first without and then with MFA.

## Why and when to use it

- Your own administrator user has MFA because you set it up yourself. But in an organisation with many users, you cannot rely on everyone doing it. Someone puts it off, and that account is the one that gets taken over.
- With a policy, MFA becomes a requirement. The user can still sign in, but cannot do anything until MFA is on.
- The effect is clear: without MFA almost everything is denied, with MFA everything works that the user's other policies allow.
- It is defense in depth in IAM. Even if a password leaks, it is not enough to reach anything, since the MFA code is also required.

## How it works

- A statement in a policy can have a condition, `Condition`. The statement only applies when the condition is met.
- AWS sends information about every call that conditions can look at. One of them is `aws:MultiFactorAuthPresent`, which is `true` when the user signed in with MFA.
- The policy has a statement with `"Effect": "Deny"` that denies everything when MFA is missing. That is the statement that does the job.
- The statement has exceptions. The user must be able to set up an MFA device, so those actions are not denied. Otherwise nobody could get started.
- An explicit `Deny` always wins over `Allow`. It does not matter that another policy gives the user permissions, the `Deny` in this policy stops it anyway.

**The policy, statement by statement**

[require-mfa-policy.json](require-mfa-policy.json) is taken verbatim from AWS's documentation, the page [AWS: Allows MFA-authenticated IAM users to manage their own MFA device on the Security credentials page](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_aws_my-sec-creds-self-manage-mfa-only.html). It has four statements. The last one, `DenyAllExceptListedIfNoMFA`, is the one that requires MFA:

```
"Effect": "Deny",
"NotAction": [ ... MFA actions ... ],
"Condition": { "BoolIfExists": { "aws:MultiFactorAuthPresent": "false" } }
```

- `"Effect": "Deny"` means that the statement denies. It only denies when the condition further down is met.
- `NotAction` is the opposite of `Action`. The statement applies to all actions except those in the list. The list only has what is needed to create and activate an MFA device, and `sts:GetSessionToken`.
- The condition uses `BoolIfExists`. According to AWS's documentation, `IfExists` makes the condition count as true even when the information about MFA is missing completely, which it is for calls made with access keys.
- The value `false` means: deny when MFA is not used. If the user signs in with MFA, the condition is not met, and then the statement denies nothing.
- The first three statements let the user see and set up their own MFA device. The variable `${aws:username}` in the resource means that each user can only manage their own.

## Prerequisites

- A test user with console access, in a group. See [IAM Identities](https://docs.aws.amazon.com/IAM/latest/UserGuide/id.html).
- Your own administrator user, which is not in that group.
- An authenticator app on your phone, for the test user's MFA. See [Assign a virtual MFA device in the AWS Management Console](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable_virtual.html).

| Placeholder | What it is | Example |
|---|---|---|
| `<prefix>` | The prefix for your resource names, see the root README | `demo` |
| `<group-name>` | The group the test user is in (IAM, User groups) | `developers` |
| `<test-user>` | The test user's name (IAM, Users) | `test-user` |

## Step by step

IAM is global in the account, so you do not need to choose a region.

### 1. Create the policy and attach it to the group

1. In IAM, choose **Policies** in the menu on the left and **Create policy**. Change to the tab **JSON** in the editor, so that you can paste the whole policy.
2. Select everything in the editor, paste the content of `require-mfa-policy.json` and click **Next**. Give the policy the name `<prefix>-require-mfa` and click **Create policy**.
3. Choose **User groups** in the menu on the left and click `<group-name>`. Go to the tab **Permissions**.
4. **Add permissions** and **Attach policies**.
5. Search for `<prefix>-require-mfa`, tick it and click **Attach policies**. Now the MFA requirement applies to everyone in the group.

### 2. Test as the test user

1. Open a private window in the browser and sign in as `<test-user>` with the account's sign-in address, **Console sign-in URL**. Then you stay signed in as administrator in the ordinary window.
2. Open S3. The list first says **Loading**, and then shows *You don't have permissions to list buckets*, with the action `s3:ListAllMyBuckets`. The policy works, and it is the `Deny` statement that stops it, but S3 says nothing about MFA.
3. Click the user name at the top right and choose **Security credentials**. The page shows several red boxes, for example *Access denied to iam:ListAccessKeys*, with the text *explicit deny in an identity-based policy* and the policy's ARN. Here you can see which policy denies. Under **Multi-factor authentication** there is still **Assign MFA device**, since the policy makes an exception for what is needed to set up MFA. Give the device a name, choose **Authenticator app** and follow the steps.
4. Sign out and sign in as `<test-user>` again. Now you are asked for the MFA code after the password.
5. Open S3 again. Now the buckets show as usual, since the sign-in was made with MFA and the condition is no longer met.

Also look at **Security credentials** again. Some red boxes remain, but the text has changed from *explicit deny* to *no identity-based policy allows*. That is the difference between an explicit denial from this policy and the user simply not having been given the permission. Both lead to something being denied, but for different reasons.

## Check the result

- Without MFA: S3 and most other things are denied, and the IAM pages show *explicit deny* with the policy's ARN.
- With MFA: everything that the user's other policies allow works.

## Clean up

The guide creates the policy `<prefix>-require-mfa` and attaches it to the group. If the requirement should not stay, detach the policy from the group: the group, **Permissions**, select the policy and **Remove**. If you do not need it any more, delete it as well: **Policies**, select `<prefix>-require-mfa`, **Delete**.

## The AWS CLI and access keys

- The policy applies to all calls, not only the console. The same IAM checks both.
- According to AWS's documentation, calls with long-term access keys count as calls without MFA. With an ordinary access key, almost everything is denied.
- To use the AWS CLI, the user must then first fetch temporary keys with `sts get-session-token` and give the MFA code. That is why that action is an exception in the policy.
- The policy is meant for groups of people who sign in.
- Never attach it to the role of a server. A server cannot use MFA, and then the condition would deny everything the server does.

## Good to know

- **Always test as the user the policy applies to,** in a private window. If you look as administrator, everything seems to work, since the administrator is not in the group.
- **The exceptions in `NotAction` are necessary.** If you remove them, the user cannot create an MFA device, and then nobody gets in. Use the policy as it is in the documentation.
- **Do not attach the policy to your own administrator user** without first testing it on a test user. A mistake in a `Deny` statement can lock you out, and then only the root user can fix it.
- **Where in the console you look decides how much the error says.** The IAM pages show *explicit deny* and the policy's ARN, so there you see directly which policy denies. S3 only says that listing is not allowed. *Explicit deny* means a `Deny` statement stops it, *no identity-based policy allows* means the permission is missing. The [IAM policy simulator](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html) can also show which statement denies.

## Common errors

| Symptom | Cause |
|---|---|
| Everything works for the test user without MFA | You are testing as administrator, or the policy is not attached to the right group. Test in a private window as the test user. |
| Nobody can set up MFA | The exceptions in `NotAction` have been removed or changed. Use the policy as it is. |
| A server's role is denied everything | The policy has been attached to the role. A server cannot use MFA. |
| The AWS CLI is denied everything with an access key | Calls with long-term access keys count as without MFA. Fetch temporary keys with `sts get-session-token` and the MFA code. |

## Files

| File | What it is |
|---|---|
| `require-mfa-policy.json` | The policy from AWS's documentation. Paste it in the JSON editor when you create the policy. |
