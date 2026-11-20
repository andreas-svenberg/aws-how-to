# 07 Last accessed information

## What it is

The tab **Last Accessed** in IAM shows when a user, a group or a role last used each service it has permissions for. You look at it for a user, a role and a group, fetch the same information with the AWS CLI, and use it to decide which permissions are actually needed.

## Why and when to use it

- **Least privilege:** a user or a role should only have the permissions needed for the job, nothing more.
- In practice, permissions are often added just in case, or a broad AWS managed policy is chosen because it is simple. After a while, nobody knows what is really used.
- Last accessed answers exactly that. For every service it shows when the identity last used it, or that it has never been used.
- A service that is never used is a candidate to remove from the policy. That reduces the damage if the user or the role is ever misused.
- It is also good evidence when you justify your permissions in documentation. You can show that you have checked what is used, not just guessed.

## How it works

- IAM keeps track of when an identity last used each service that its policies give access to. For some services, among them S3, it is also kept for individual actions.
- The tab exists for users, groups, roles and policies. On a group or a policy, you can also see which of the members have used the service.
- According to AWS's documentation, the tracking covers the last 400 days. That is enough to see patterns, also for things that are only done once a year.
- If it says **Not accessed in the tracking period**, the service has not been used at all during the period. Those are the rows to look for.
- The information is not updated the same second as the call is made. If you test something and look directly afterwards, it can look as if nothing happened. Wait a while and reload.

## Prerequisites

- An IAM user, group or role with one or more policies attached. See [IAM Identities](https://docs.aws.amazon.com/IAM/latest/UserGuide/id.html).
- A user in the console that may read IAM, for example an administrator.
- For the CLI part: CloudShell, or the AWS CLI on your computer. See [Getting started with AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/getting-started.html).

| Placeholder | What it is | Example |
|---|---|---|
| `<user-name>` | The name of an IAM user (IAM, Users) | `developer` |
| `<account-id>` | Your account id, 12 digits (top right in the console) | `123456789012` |
| `<job-id>` | The id that the first CLI command prints | `examplef-1305-c245-eba4-71fe298bcda7` |

## Step by step

IAM is global in the account, so you do not need to choose a region.

### 1. Last accessed for a user

1. Open IAM, choose **Users** in the menu on the left, and click the user.
2. Choose the tab **Last Accessed** on the user's page. The list is called **Allowed services** and shows the services that the user's policies give access to.
3. For every service it says when it was last used, or that it has not been used.
4. Compare with the policies. If the user gets its permissions from a group, the list shows what the group's policies open up, and what of that has been used.

### 2. Last accessed for a role

1. Choose **Roles** in the menu on the left, click the role and the tab **Last Accessed**. There you see when the role last used each service.
2. Also look at the top under **Summary**. There it says **Last activity**, for example `6 minutes ago`. The tab Last Accessed can at the same time still say **Not accessed**. That is the delay.

### 3. The same with the AWS CLI

It is done in two steps. Run it in CloudShell, where you are already signed in.

1. Ask IAM to produce a report for an identity. The command needs the identity's ARN. For a user it is `arn:aws:iam::` followed by the account id, `:user/` and the user's name. The command answers with a `JobId`, a long string that you copy.

   ```
   aws iam generate-service-last-accessed-details --arn arn:aws:iam::<account-id>:user/<user-name>
   ```

2. Fetch the result with the job's id. It is the same id that the first command printed, and it only applies to this report.

   ```
   aws iam get-service-last-accessed-details --job-id <job-id>
   ```

The report is produced in the background. If `JobStatus` says `IN_PROGRESS`, run the same `get` command again after a while, until it says `COMPLETED`.

### 4. A group: Access Advisor

1. Choose **User groups** in the menu on the left and click the group. On a group, the tab is called **Access Advisor**, not Last Accessed, but it shows the same thing.
2. The column **Access by members** shows which of the members have actually used each service.

An example: a group with the AWS managed policy `AmazonEC2FullAccess`. If you open the policy, you see that it does not only apply to EC2. It also gives permissions in related services, such as Auto Scaling, load balancers and metrics in CloudWatch, and even a small part of IAM: the right to create service-linked roles. So IAM is also in the list. If only EC2 is used, a narrower policy of your own may be enough.

## Check the result

- In the console, every service in the list has a date, or **Not accessed in the tracking period**.
- In the CLI answer, a service that has been used has the field `LastAuthenticated` with a time. A service that has never been used lacks that field and only has `TotalAuthenticatedEntities` `0`.

**What the answer means:**

- **A date:** the service is used. If it was recently, the permission is probably needed, and you leave it.
- **Never used:** a candidate to remove. Ask yourself whether the user or the role really should be able to do it.
- **Be careful with new users and roles.** If one was created recently, it is natural that much has not been used yet.
- **Look at a longer period** before you remove anything, preferably a couple of months, and ask whoever uses the account. Something that runs once a quarter does not show in a week.
- **Test a narrower policy** with the [IAM policy simulator](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html) before you replace the old one. Then you see directly whether something necessary disappears.

## Clean up

The guide only reads information. There is nothing to remove.

## Good to know

- **The information is updated with a delay.** If you have just done something and it does not show, wait a while before you draw conclusions.
- **For most services, only the service as a whole is shown.** For some, among them S3, you can see individual actions, such as reading or listing. That makes it easier to write a narrow policy.
- **On users and roles the tab is called Last Accessed, on groups Access Advisor.** Do not look for Last Accessed on a group.
- **Do not remove a permission only because it has not been used yet.** Last accessed is evidence for a decision, not a decision in itself.
- **Write down your reasoning.** That you have looked at what is used and taken a position is worth a few sentences in your documentation.

## Common errors

| Symptom | Cause |
|---|---|
| A service that you just used says **Not accessed** | The information is updated with a delay. Wait a while and reload. |
| No tab **Last Accessed** on a group | On groups it is called **Access Advisor**. |
| `JobStatus` is `IN_PROGRESS` | The report is not ready yet. Run the `get` command again after a while. |
| `NoSuchEntity` | The identity in the ARN does not exist. Check the name in the ARN. |
| `InvalidInput` | A value in the command is not valid, for example an ARN that is not written correctly. |

## Files

This guide has no files.
