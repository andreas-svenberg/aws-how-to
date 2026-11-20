# 06 Temporary credentials from a role

## What it is

A server with an IAM role can run AWS CLI commands without anyone having typed in any keys. This guide shows how that works: you ask AWS which identity the server has, read which keys the server has been given from the instance metadata service, and see that they are replaced automatically.

## Why and when to use it

- **Every call to AWS must be signed with keys,** also when it comes from a server. Without keys, the AWS CLI answers `Unable to locate credentials`.
- **With a role, nobody needs to type in any keys.** No file with keys is on the server, and nobody needs to remember to change them.
- **The keys from a role are temporary.** They have an expiry time, and AWS replaces them well before they stop working.
- **A key that leaks,** for example in a log or a screenshot, stops working by itself after a while. An ordinary access key keeps working until someone removes it.
- **The keys come from the same metadata service** that gives the instance id and the zone (guide 03). Same address and same token, just another path.

## How it works

- A role cannot be attached directly to a server. It is put in an **instance profile**, a container for the role. When you choose the role in the console, the instance profile is created automatically.
- When the server has an instance profile, the metadata service hands out temporary keys for the role. Only the server itself can ask, the address `169.254.169.254` cannot be reached from the outside.
- The path is `iam/security-credentials/` followed by the role's name. Asking without a role name gives back the name of the role, and the script in this guide uses that.
- The AWS CLI and the programming libraries, the SDKs, automatically look for keys there when nothing else is set up. That is why AWS CLI commands work without you doing anything.
- According to AWS's documentation, the keys are replaced automatically, and new keys are available at least five minutes before the old ones stop working. There is no interruption when the replacement happens.

## Prerequisites

- An EC2 instance running Amazon Linux 2023, with an IAM role attached, that you can log in to with SSH. See [IAM roles for Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html).
- The key file for the instance's key pair.

| Placeholder | What it is | Example |
|---|---|---|
| `<key>` | The name of your key file, without `.pem` (on your computer) | `my-key` |
| `<public-ip>` | The instance's public IPv4 address (EC2, Instances, the instance) | `203.0.113.10` |

## Step by step

### 1. Which role does the server have?

1. Log in to the server with SSH. Check in the console, under the tab **Security** for the instance, that it has a role.

   ```
   ssh -i ~/.ssh/<key>.pem ec2-user@<public-ip>
   ```

2. Ask AWS who is calling. `sts get-caller-identity` needs no special permissions, it works for anyone with valid keys.

   ```
   aws sts get-caller-identity
   ```

3. The command prints three fields: `UserId`, `Account` and `Arn`. Look at `Arn`. On your own computer it says `user` and your user's name. Here it says `assumed-role`, a role that has been assumed:

   ```
   arn:aws:sts::<account-id>:assumed-role/<role-name>/<instance-id>
   ```

   After `assumed-role` comes the role's name and then the instance id. AWS uses the instance id as the name of the session, so the logs show which server made the call.

No key has been typed in on the server, and there is no file with keys in the home folder. Still, the server is signed in as the role.

### 2. Read the keys in the metadata service

[show-role-credentials.sh](show-role-credentials.sh) does the same as the AWS CLI does in the background. It fetches an IMDSv2 token, asks for the role's name, and then for the keys of the role.

1. Copy the script to the server with `scp` from your computer. You can also type the lines in by hand, the script is short.

   ```
   scp -i ~/.ssh/<key>.pem show-role-credentials.sh ec2-user@<public-ip>:~
   ```

2. Run it on the server.

   ```
   bash show-role-credentials.sh
   ```

3. The script first prints the role's name, then some lines from the answer. `Code` should be `Success`. If it says something else, something is wrong with the role.

The answer also contains `SecretAccessKey` and `Token`, the secret parts. The script filters them out with `grep`, so that the result can be shown to others without showing the secrets.

## Check the result

- `AccessKeyId` starts with `ASIA`. That is AWS's way of marking temporary keys, those that come from a role or a temporary session. An ordinary access key, created for a user under Security credentials, starts with `AKIA` instead. If you see `AKIA` in a file on a server, it is a long-lived key, and you should ask yourself why it is there.
- `Expiration` is the time when the keys stop working, in UTC. Compare with the clock, and you see that it is not far ahead.
- `LastUpdated` is the time when the metadata service last fetched new keys for the server.
- Run the script again later, after `Expiration` has passed. Then `AccessKeyId` has been replaced, without you doing anything, and without the AWS CLI on the server stopping working.

## Clean up

The script file is the only thing the guide leaves on the server. You can remove it:

```
rm show-role-credentials.sh
```

## A role compared with an access key

| Access key for a user | Keys from a role |
|---|---|
| Valid until someone deactivates or removes it. If it is forgotten, it can work for years. | Valid for a limited time and replaced by AWS. Nobody needs to remember to rotate them. |
| Must be stored somewhere on the server, usually in the file `credentials` in the folder `.aws`. It can end up in a backup, an image of the server or in git. | Fetched from the metadata service when needed. They are not in any file that can be copied by mistake. |

A server in AWS should get its permissions through a role, never through access keys. That is also what AWS recommends.

## Good to know

- **Do not show the full answer** from the metadata service to others, and do not paste it into a chat or a document. It contains the secret key and the token. Use the script, which filters them out.
- **To change the role** on a server that is already running, it does not need to be restarted. Select the instance, **Actions, Security, Modify IAM role**, and choose the new role.
- **The keys give no more than the role's policies allow.** A command that the role is not allowed to run is denied, even though the server has valid keys.

## Common errors

| Symptom | Cause |
|---|---|
| `Unable to locate credentials` | The server has no role. Nothing is broken, the server just has not been given an identity. |
| No answer from the metadata service | The IMDSv2 token is missing. Amazon Linux 2023 requires a token for every question. It can look as if the role is missing. |
| `Code` is not `Success` | Something is wrong with the role. Check it under the tab **Security** for the instance. |
| `AccessDenied` for a command | The role's policies do not allow the action. |

## Files

| File | What it is |
|---|---|
| `show-role-credentials.sh` | Shows the role's name and `Code`, `LastUpdated`, `AccessKeyId` and `Expiration`, without the secret key and the token. Run it on the server. |
