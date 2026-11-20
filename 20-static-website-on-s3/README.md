# 20 Static website on S3

## What it is

A page that only consists of ready-made files does not need a web server: S3 can deliver it by itself. You create a new bucket, turn on static website hosting, open just that bucket for reading and upload a page. Then you look at cost, and at why this is the only kind of bucket that should be public. Everything is done in the S3 console and CloudShell.

## Why and when to use it

- **A web server on an instance must run around the clock,** be updated and be monitored, even if the page never changes.
- **A page that only consists of ready-made files** (HTML, images, CSS and JavaScript) is called static. S3 can send such files directly to the browser, since they are just files to be read.
- **Without a server there is no operating system to patch,** no web server to restart and no disk that can get full. There is less to look after and less that can break.
- **S3 handles many visitors without you doing anything.** There is no instance size to choose. You only pay for storage and for the requests that are actually made.
- **The drawback is that S3 runs no code.** There is no PHP and no database connection, so WordPress cannot be hosted this way. A campaign page or a simple information page works.

## How it works

Four things are needed for a bucket to work as a website:

- **Static website hosting is turned on** in the bucket's properties, with `index.html` as index document. That is the file S3 returns when someone asks for the address without a file name.
- **Block public access is turned off for just this bucket.** That protection exists to prevent buckets from becoming public by mistake, and here you actually want the bucket to be public.
- **A bucket policy gives everyone, `Principal` `*`, the right to `s3:GetObject`,** that is to read objects. No other rights: nobody can list, write or delete.
- **The website gets an address of its own,** different from the bucket's ordinary address. It only works with `http`, not `https`:

  ```
  http://<bucket-name>.s3-website.<region>.amazonaws.com
  ```

  `s3-website` shows that it is the website's address and not the bucket's ordinary address for files. In some older regions a dash is used instead of the dot before the region, so always copy the address from the console instead of writing it from memory. See [Website endpoints](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html).

## Prerequisites

- A user that may create buckets and change their permissions, signed in to the console so that you can use [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html). See [Tutorial: Configuring a static website on Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/HostingWebsiteOnS3Setup.html).

| Placeholder | What it is | Example |
|---|---|---|
| `<bucket-name>` | A new bucket name. Bucket names are unique across all of AWS, so include something of your own | `my-site-bucket-01` |
| `<region>` | The region where you create the bucket | `eu-north-1` |

## Step by step

### 1. Create the bucket and turn on the website

1. Open S3 in the console, check the region, and click **Create bucket**. Name it `<bucket-name>`. Leave the other choices as they are, also Block public access, which you change in step 4.
2. Open the bucket and choose the tab **Properties**. Further down the page is the box **Static website hosting**, and for a new bucket it is turned off.
3. Click **Edit**, choose **Enable** and type `index.html` as **Index document**. Click **Save changes**. Now the box shows the bucket's website address. Copy it.
4. Choose the tab **Permissions**. At the top is the box **Block public access**, which says that all public access is blocked. Click **Edit**, clear **Block all public access** and click **Save changes**. The console asks you to confirm by typing `confirm`, a sign that you are doing something that requires thought.
5. Check also that the account as a whole does not block public access. That setting is in the menu on the left in S3.

### 2. Make the files readable

1. Stay on the tab **Permissions** and go down to the box **Bucket policy**. It is empty for a new bucket. Click **Edit**.
2. Open [public-read-policy.json](public-read-policy.json) in a text editor, copy everything from the first curly bracket to the last and paste it in the editor. The console marks lines with errors, for example a missing quotation mark.
3. Replace `<bucket-name>` in the line `Resource` with your bucket's name, so that it points at your bucket. Click **Save changes**. If it works, the console shows that the bucket is now public, and that is right.

Look at the policy:

- **`Principal` is `"*"`,** which means everyone, also those who are not signed in to AWS.
- **`Action` is only `s3:GetObject`,** that is reading a file whose name you already know.
- **`Resource` is the bucket's ARN followed by `/*`,** that is all objects in the bucket.
- **`s3:ListBucket` is not included,** so nobody can get a list of which files exist.

If the console refuses to save the policy, it is almost always because Block public access is still on, either for the bucket or for the whole account. Go back to step 1 and check both.

### 3. Upload the page

1. Open CloudShell and upload two files with **Actions** and **Upload file**: [upload-website.sh](upload-website.sh) and [index.html](index.html). You can use your own `index.html` instead. See also [guide 05](../05-files-in-cloudshell/).
2. Run the script with the bucket's name:

   ```
   bash upload-website.sh <bucket-name>
   ```

   The script copies the page to the bucket as `index.html` and tells S3 that it is an HTML page. Then it prints the website's address and tries it with `curl`. If it says `HTTP status: 200`, everything works.

3. Copy the address and open it in an ordinary browser tab. Note that it starts with `http` and not `https`, and that the browser may warn that the page is not secure. Now the page is shown, without any server running. It is S3 that answers.

## Check the result

- The script prints `HTTP status: 200`, and the page is shown in the browser.
- `404` means that there is no `index.html` in the bucket. Check the spelling.
- `403` means that read access is missing: the bucket policy or Block public access is not right. The difference tells you directly where to look.

## Clean up

A bucket must be empty before it can be deleted. In the console, empty it with **Empty** and then delete it with **Delete**. In CloudShell, `--force` empties and deletes in one step:

```
aws s3 rb s3://<bucket-name> --force --region <region>
```

## What does it cost?

Very little for a small page, but not nothing. See [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/) for the current prices in your region.

- **Storage is paid per GB and month.** A small page is a few kilobytes, so that cost is negligible.
- **Every time someone fetches a file, it is a request,** and requests are priced per thousand. For a page with a few visits a day, it is very small amounts.
- **Traffic out to the internet** is normally paid per GB, but a certain amount per month is free.
- **Compare with a web server on an instance,** which costs for every hour it runs, whether anyone visits the page or not. A static page in S3 costs nothing when nobody looks.
- **HTTPS and a domain of your own** need a service in front of the bucket, for example Amazon CloudFront or AWS Amplify Hosting. That is not covered here, and it can add costs.

## Good to know

- **This is the only kind of bucket that should be public.** It only contains what should be shown to everyone anyway. A bucket with backups or other data should never be public. To share a single file, use a presigned URL instead, see [guide 18](../18-share-a-file-with-a-presigned-url/).
- **Block public access exists both for the bucket and for the account.** If you turned it off for the bucket but it still does not work, check the setting for the account. Only change it if you understand what it protects.
- **S3 only delivers files as they are.** A contact form that should send mail, or a page that reads from a database, does not work, since that needs code on a server.

## Common errors

| Symptom | Cause |
|---|---|
| The console refuses to save the bucket policy | Block public access is still on, for the bucket or for the account. |
| `403 Forbidden` | The bucket policy is missing or wrong, or Block public access is on. |
| `404 Not Found` | There is no `index.html` in the bucket, or the name is misspelled. |
| The page does not load | The address starts with `https`. S3 website endpoints do not support HTTPS, use `http`. Or the address was written by hand with the wrong format for the region: copy it from **Static website hosting** in the console. |

## Files

| File | What it is |
|---|---|
| `public-read-policy.json` | The bucket policy: everyone may read the objects in the bucket, nothing more. |
| `upload-website.sh` | Uploads `index.html` to the bucket, prints the website address and tests it with `curl`. |
| `index.html` | A simple example page. |
