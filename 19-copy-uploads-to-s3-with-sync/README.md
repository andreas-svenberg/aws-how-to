# 19 Copy uploads to S3 with sync

## What it is

A database dump of a WordPress site contains everything in the database, but not the files that have been uploaded. They are stored in `wp-content/uploads`, and if they disappear, the database points to images that do not exist. You give the web server's role the right to write under a new prefix in a backup bucket, copy the folder `uploads` to S3 with `aws s3 sync`, and see that the second run only copies what is new.

## Why and when to use it

- **A backup that only covers half of the site is not enough** when something breaks.
- **A database dump contains all tables:** posts, pages, users and settings.
- **The images uploaded in WordPress end up as files** in the folder `uploads` under `wp-content`, here on Amazon EFS, and they are not in the dump.
- **The database has a row for each image,** in the table `wp_posts`, with a path to the file. If you restore a dump on a new server without the images, WordPress shows posts with broken images.
- **`aws s3 sync` compares a folder with a prefix in S3 and copies what differs.** It is made for exactly this kind of task: keeping a copy of a folder.
- **The first time, everything is copied.** The next time, only files that have been added or changed are copied, so the run is fast and makes very few requests, even when the folder grows.

## How it works

```
aws s3 sync /var/www/html/wp-content/uploads s3://<bucket-name>/uploads/ --region <region>
```

- **First comes the source,** the folder `uploads` under `/var/www/html/wp-content` on the server. It is the folder where WordPress puts everything that is uploaded.
- **Then the target,** the bucket followed by `uploads/`. The images get a prefix of their own, so that they are not mixed with other content in the bucket, for example database dumps under `backup/`.
- **Last the region.** Giving it in the command means that you do not depend on any setting in the AWS CLI on the server.
- **sync compares each file in the source with the target.** A file is copied if it is missing in the target, if the size differs, or if the local file is newer. Files that are the same are not touched.
- **`--dryrun` makes sync only print what would be copied,** without copying anything. Always run with `--dryrun` first when you try a new sync command. It costs nothing and shows whether the source and target are right.
- **`--delete` removes files in the target that no longer exist in the source.** That sounds tidy, but for a backup it is dangerous. If someone deletes an image in WordPress by mistake, the next sync deletes the copy too, and then there is no backup left.

## Prerequisites

- A web server running WordPress, with `wp-content` on Amazon EFS mounted on `/var/www/html/wp-content`, and an IAM role attached to the server. See [IAM roles for Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html).
- A private S3 bucket for backups, in the same region.
- SSH access to the web server, and `scp` to copy the script to it.
- A user that may change the role's policies in IAM, for example an administrator.

If your uploads are in another folder, change `SRC` at the top of `sync-uploads-to-s3.sh`.

| Placeholder | What it is | Example |
|---|---|---|
| `<bucket-name>` | The name of your backup bucket (S3, Buckets) | `my-backup-bucket-01` |
| `<role-name>` | The role attached to the web server (EC2, the instance, Security, IAM Role) | `demo-ec2-role` |
| `<prefix>` | The prefix for your resource names, see the root README | `demo` |
| `<region>` | The bucket's region | `eu-north-1` |

## Step by step

### 1. Give the role the right to write

Before sync can work, the role on the server needs the right to list the bucket and write under `uploads/`.

1. Open IAM in the console and choose **Roles** in the menu on the left. Search for the role so that the list gets short, and click on `<role-name>`. Under the permissions, you see the policies the role already has.
2. Choose **Add permissions** and **Create inline policy**. Choose the **JSON** mode instead of the visual editor. Remove what is there and paste the content of [uploads-policy.json](uploads-policy.json). Replace `<bucket-name>` with your bucket's name in both places, otherwise the policy points at a bucket that does not exist.
3. Go on, name the policy `<prefix>-s3-uploads` and create it. It shows in the role's list of policies.

The policy has two parts:

- **`s3:ListBucket` applies to the bucket itself.** It is needed so that sync can list what is already in the target.
- **`s3:PutObject` only applies to `uploads/` and everything under it.**
- **`s3:GetObject` is not needed.** sync downloads nothing when you copy from the server to S3.

### 2. Dry run and real run

1. Copy [sync-uploads-to-s3.sh](sync-uploads-to-s3.sh) to the web server with `scp`, and log in to the server with `ssh`. With a bastion host, both `scp` and `ssh` work through `ProxyJump` as usual, see [guide 13](../13-ssh-tunnel-through-a-bastion/).
2. Start with a dry run. The script takes the bucket's name as its first argument and passes options like `--dryrun` on to `aws s3 sync`:

   ```
   bash sync-uploads-to-s3.sh <bucket-name> --dryrun
   ```

   The script first checks that the folder `uploads` exists, so that you notice directly if EFS is not mounted. The output gets one line per file starting with `(dryrun) upload:`, followed by the file's path and the target in S3. Nothing is copied. Check that the target ends in `uploads/`.

3. When the dry run looks right, run the same command without `--dryrun`:

   ```
   bash sync-uploads-to-s3.sh <bucket-name>
   ```

   Now the lines show without `(dryrun)` in front, and the files are uploaded for real. If you get `AccessDenied`, it is almost always the policy from step 1, see Common errors. The script refuses to run with `--delete`, for the reason above.

### 3. Only the new files are copied

1. Sign in to the WordPress admin pages and upload a new image under **Media**.
2. Go back to the SSH window on the web server and run the same command again:

   ```
   bash sync-uploads-to-s3.sh <bucket-name>
   ```

   You do not need to say which file is new, sync works it out itself. Now there are only a few lines: the new image, and the smaller versions that WordPress creates automatically of every uploaded image. All other files are the same and are skipped.

3. Open S3 in the console, click on the bucket and then on the folder `uploads`. Under `uploads/` there are folders for year and then month, just as on the server. WordPress sorts uploads that way, and sync keeps the same structure. That is why the images can be put back in the same place if they disappear.

## Check the result

- The second run only copies the new image and its smaller versions.
- In the S3 console, `uploads/` has the same year and month folders as on the server.

## Clean up

The copies in S3 and the policy are the result, and should stay if you want to keep the backup. If you only tried it out, remove the copies and the inline policy:

```
aws s3 rm s3://<bucket-name>/uploads/ --recursive --region <region>
```

```
aws iam delete-role-policy --role-name <role-name> --policy-name <prefix>-s3-uploads
```

## sync compared with cp, and lifecycle rules

| `aws s3 cp --recursive` | `aws s3 sync` |
|---|---|
| Copies all files every time, whether they already exist in the target or not. | Compares first and only copies what differs. For a folder with hundreds of images where only a few are added each day, it is much faster and makes fewer requests. |

- **A lifecycle rule that removes objects after a number of days** can apply to only one prefix, for example `backup/` for old database dumps. Then everything under `uploads/` is not covered. The images stay until someone removes them, and that is right: an image from last year is still needed if it is shown on the site.
- **Since `--delete` is not used, images deleted in WordPress also stay in S3.** It costs a little storage over time, but it means that an image deleted by mistake can be fetched back.

## Good to know

- **Never add `--delete` to a backup command without thinking it through.** A backup should protect against mistakes, and with `--delete` the mistake follows to the copy at the next run.
- **Always run sync on the web server,** or another server where EFS is mounted. That is where the folder `uploads` is. On your own computer or in CloudShell there are no images to copy.
- **The backup bucket covers the whole site** when it has both the database in the dumps and the files under `uploads/`. Both are needed to rebuild WordPress on a new server.

## Common errors

| Symptom | Cause |
|---|---|
| `AccessDenied` directly when sync tries to list the target | `s3:ListBucket` is missing. Check that the `Resource` for that statement is the bucket itself, without slash and star at the end. ListBucket applies to the bucket, not the objects. |
| Listing works but every upload is denied | `s3:PutObject` points at the wrong place. `Resource` should end in `uploads/*`. |
| *not found. Is EFS mounted* | EFS is not mounted on `/var/www/html/wp-content`, or the script is run on the wrong computer. |
| *Permission denied* on some files | Some files cannot be read by your user. Run the script with `sudo`. |

## Files

| File | What it is |
|---|---|
| `uploads-policy.json` | The inline policy for the server's role: list the bucket and write under `uploads/`. |
| `sync-uploads-to-s3.sh` | Runs `aws s3 sync` from the uploads folder to `uploads/` in the bucket, and refuses `--delete`. |
