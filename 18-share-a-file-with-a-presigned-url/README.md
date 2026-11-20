# 18 Share a file with a presigned URL

## What it is

Sometimes someone outside your account needs a single file from a private bucket. A presigned URL lets you share it without making the bucket public and without creating a new IAM user. It is a link that is signed with your own keys and that stops working after a time you choose. You put a file in a private bucket, show that the ordinary address is denied, create a link that is valid for five minutes and watch it stop working. Everything is done in CloudShell.

## Why and when to use it

- **The bucket is private, and should stay that way.** Only identities in your account with the right policy can read in it.
- **Sometimes someone outside still needs a single file,** for example a report for an auditor, or an export file that a consultant needs for an afternoon.
- **An IAM user for a one-time share is too much.** The user must be looked after, get the right policy and be removed afterwards. If you forget it, it stays in the account.
- **A presigned URL gives temporary read access.** You who already have read access create a link that carries your permission with it, and whoever gets the link can open the file in an ordinary browser without signing in.
- **The link only works for that file,** not for the rest of the bucket, and only for a limited time that you choose when you create it. Then it stops working by itself.

## How it works

```
aws s3 presign s3://<bucket-name>/<key> --expires-in 300 --region <region>
```

- **Every request to S3 must be signed.** When you run `aws s3 ls`, the AWS CLI signs the request with your keys. With `presign`, the AWS CLI makes the same signature, but puts it in a link instead of sending the request itself.
- **`<key>` is the file's name and path in the bucket,** the word S3 uses for it.
- **`--expires-in 300` means 300 seconds,** five minutes. The command prints a long https address, and that is the one you share.
- **Without `--expires-in`, the link is valid for 3600 seconds,** one hour. The highest value is 604800 seconds, seven days. A presigned URL cannot be made valid for longer than that.
- **The link contains parameters starting with `X-Amz`.** `X-Amz-Algorithm` is `AWS4-HMAC-SHA256`, `X-Amz-Expires` is the number of seconds and `X-Amz-Signature` is the signature itself. If someone changes a single character in the link, the signature no longer matches and S3 denies the request.
- **The link never gives more than you have yourself.** Whoever signs must have `s3:GetObject` on the object, otherwise whoever opens the link is denied, just as you would have been.

## Prerequisites

- A private S3 bucket, with **Block public access** turned on. See [Sharing objects with presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html).
- A user that may upload and read objects in the bucket, signed in to the console so that you can use [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html).

| Placeholder | What it is | Example |
|---|---|---|
| `<bucket-name>` | The name of your private bucket (S3, Buckets) | `my-data-bucket-01` |
| `<region>` | The bucket's region | `eu-north-1` |

## Step by step

### 1. Private file, denied address

1. Sign in to the console, check that the region is the bucket's region, and open CloudShell with the icon at the top of the console.
2. Upload [share-file-with-presigned-url.sh](share-file-with-presigned-url.sh) to CloudShell, with **Actions** and **Upload file**. The file ends up in the home folder. Run `ls` to see that it arrived. See also [guide 05](../05-files-in-cloudshell/).
3. Run the script with the bucket's name as argument:

   ```
   bash share-file-with-presigned-url.sh <bucket-name>
   ```

   The script creates a small text file, `hello.txt`, copies it to the bucket with `aws s3 cp` and then prints two addresses.

4. Copy the first address, the one ending in `hello.txt` with nothing after it, and open it in a new browser tab. It is the file's ordinary address in S3, with the bucket's name first. The answer is a short XML document with the code `AccessDenied`. That is exactly what you want to see: the bucket is private, and an anonymous browser may not read anything in it, not even if it knows exactly what the file is called.

### 2. Open the link and wait

1. Copy the second address that the script printed, the one that is much longer. Open it in a private window, so that it shows that no sign-in is used. Now the content of `hello.txt` is shown directly in the browser. Same file, same bucket, but now with the signature in the address. It is the signature that makes the difference, not that the bucket has changed.
2. Look at the address. After the question mark come the parameters, and there you find `X-Amz-Expires=300`, `X-Amz-Algorithm` and the long `X-Amz-Signature`. Note the time when the link was created.
3. Wait five minutes, then go back to the tab and reload the page. Now S3 answers with an error instead of the file's content. The link has expired, and it cannot be extended.

If the recipient needs the file again, create a new link directly with `aws s3 presign` and the file's address, without the script. Without `--expires-in`, the new link gets the default time, one hour. Add `--expires-in` if you want another time.

```
aws s3 presign s3://<bucket-name>/hello.txt --region <region>
```

## Check the result

- The ordinary address gives `AccessDenied`.
- The presigned URL shows the file's content without sign-in, as long as it is valid.
- After the chosen time, the presigned URL gives an error.
- Nothing has been changed in the bucket: Block public access and the policy are the same as before.

## Clean up

When the sharing is done, remove the file from the bucket so that it does not stay there unnecessarily, and the test file in CloudShell:

```
aws s3 rm s3://<bucket-name>/hello.txt --region <region>
```

```
rm hello.txt
```

## How long is the link valid?

The time you give with `--expires-in` is not always the time the link is actually valid. The link stops working at the time you chose, or when the keys that signed it stop working, whichever comes first. The signature is made with the keys, and when they are no longer valid, neither is the link.

| Signed with | The link is valid at most |
|---|---|
| An IAM user's access key (starts with `AKIA`) | Up to 7 days, since the key is valid until someone removes it |
| An instance role on a server | About 6 hours, even if you write 604800. The role's keys are temporary, see [guide 06](../06-temporary-credentials-from-a-role/) |
| Another role session, for example after assuming a role | Until the session ends, by default one hour |
| The console | You choose between 1 minute and 12 hours |

The console can also create a presigned URL for an object in S3. That is practical for those who do not want to use the command line.

## Presign compared with a public bucket

| Public bucket | Presigned URL |
|---|---|
| Everyone on the internet gets read access to all files that the policy covers, until someone changes it back. | One file, a limited time. Whoever gets the link cannot list the bucket or guess other files. |
| Block public access must be turned off and a bucket policy added: two changes to the bucket's security, and both can go wrong. | Nothing is changed in the bucket. Block public access stays on, and the policy is the same as before. |

The same rule applies on a server. If you run `aws s3 presign` on an instance, the link is signed with the instance's role, and it can only give read access to what the role itself may read. A server can never share more than that.

## Good to know

- **The link is like a key.** Anyone who gets hold of it can open the file until it expires, even if it ends up in the wrong mail or in a chat. Choose a short time.
- **Never share a presigned URL to a backup bucket** with database dumps. They can contain personal data, such as users and e-mail addresses. The script therefore refuses if the bucket name contains `backup`.
- **`aws s3 presign` calculates the signature on your own computer and does not ask S3 first.** It creates a link even if the file does not exist or if you lack `s3:GetObject`. The error only shows when someone opens the link.
- **The link can stop working earlier than you chose.** If you signed with a role session or on a server, the link may have expired although you wrote a longer time. Sign with an identity whose keys last long enough.

## Common errors

| Symptom | Cause |
|---|---|
| The presigned URL gives `AccessDenied` directly | The one who signed lacks `s3:GetObject` on the object, or the file does not exist. |
| The presigned URL stops working earlier than expected | It was signed with temporary keys (role session or instance role) that expired first. |
| The presigned URL gives an error after you copied it | A character is missing or changed, and the signature no longer matches. Copy the whole address. |
| The script says *Refusing* | The bucket name contains `backup`. Do not share files from a backup bucket. |

## Files

| File | What it is |
|---|---|
| `share-file-with-presigned-url.sh` | Uploads a test file to the bucket and prints the ordinary address and a presigned URL. The clean-up commands are at the top. |
