# 05 Files in CloudShell

## What it is

How to move files between your computer and CloudShell, the terminal built into the AWS console. You upload and download files, pack several files into one, and use git directly in CloudShell.

## Why and when to use it

- You write a script on your computer, for example user data or a command with the AWS CLI, and want to run it against your account. Then the file has to get to CloudShell.
- The other way round: you produce a list of your instances or an excerpt for your documentation in CloudShell, and want it on your computer.
- CloudShell has the AWS CLI ready and is already signed in as the user you have in the console. You do not need to install or configure anything on your computer.
- No key and no `scp` command are needed. Upload and download are done with a menu in the browser.
- What you put in the home folder stays until the next time you open CloudShell, so you can build up a folder with your scripts.

## How it works

- You get **1 GB of storage per region** that is kept between sessions, and it costs nothing. That is plenty for scripts and text files.
- **Only the home folder is kept**, `/home/cloudshell-user`. If you put files anywhere else, for example in `/tmp`, they are gone next time.
- **Every region has its own home folder.** If you open CloudShell in one region, you do not see the files you saved in another. Check the region at the top right if a file seems to have disappeared.
- If you do not use CloudShell in a region for **120 days**, the storage there is deleted. Keep important files in a repository as well.
- If you do not touch the keyboard or the mouse for **20 to 30 minutes**, the session is closed. The files in the home folder are kept, but anything that was running is stopped.

## Prerequisites

- A user in the AWS console that is allowed to use CloudShell. See [Getting started with AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/getting-started.html).
- For step 4: a public git repository.

| Placeholder | What it is | Example |
|---|---|---|
| `<file>` | The name of a file on your computer | `user-data.sh` |
| `<account>` | Your GitHub account name (github.com, top right) | `my-account` |
| `<repo>` | The repository's name | `my-site` |

## Step by step

### 1. Upload a file

1. Click the CloudShell icon at the top of the console. To get all menu choices, open CloudShell in a tab of its own. See [Common errors](#common-errors).
2. In CloudShell, the menu **Actions**, and **Upload file**. It is the same menu that is used for download in step 2.
3. **Browse**, choose the file on your computer, and click **Upload**. A progress bar shows how it goes.
4. When the upload is done, a green box shows *File upload successful*, which also says where the file ended up, `/home/cloudshell-user`. Check that the file is there:

   ```
   ls
   ```

   And, if you want to check that it is the right version:

   ```
   cat <file>
   ```

The file always ends up in the root of the home folder, whatever folder you are in. If you want it somewhere else, move it with `mv` afterwards.

### 2. Download a file

1. Create a file to download. This command writes a table of the instances, and the arrow saves it in the file `instances.txt` instead of on the screen:

   ```
   aws ec2 describe-instances --output table > instances.txt
   ```

2. **Actions** and **Download file**. A small window asks which file to download.
3. In the box, type the path to the file. A relative path counts from the home folder, so `instances.txt` is enough. If the file is in a subfolder, include the folder, for example `scripts/instances.txt`.
4. **Download**, and the browser saves the file like any download.

### 3. Several files: pack them first

Upload and Download handle one file at a time. If several files are to be moved, pack them into one first.

In CloudShell, `zip -r` packs a whole folder with all its content into a zip file, which you then download:

```
zip -r scripts.zip scripts/
```

The other way: upload a zip file and unpack it with `unzip`. The folder with all its files shows up in the home folder.

```
unzip scripts.zip
```

On Windows, you create a zip file by right-clicking the folder and choosing to compress it. The same unpacks a zip file you have downloaded.

If the folder is a cloned git repository, the hidden folder `.git` comes along. That does no harm, but the zip file gets bigger and you see many lines with `.git` when it is packed.

### 4. Alternative: git in CloudShell

If the files are already in a repository, there is a simpler way. git is installed in CloudShell, so you do not need to upload anything.

1. Clone the repository to the home folder. It stays there until next time.

   ```
   git clone https://github.com/<account>/<repo>.git
   ```

2. If you have changed something on your computer and pushed, fetch the latest version in the folder:

   ```
   cd <repo> && git pull
   ```

Pushing from CloudShell requires signing in to GitHub with a token. It works, but it is simpler to change files on your computer, push from there and only fetch in CloudShell. Then there is only one place where the files are changed.

**Pasting commands:** if you paste several lines at once, CloudShell shows the box *Safe Paste for multiline text*, where you check the text and click **Paste**. Sometimes the first line still goes wrong, for example the shell asks *Display all possibilities* and only part of the command is run. Paste one line at a time, and you also see the answer to each command.

## Check the result

- After an upload, `ls` shows the file in the home folder.
- After a download, the file is in the browser's download folder.
- After a clone, the repository's folder is in the home folder.

## Clean up

The files you uploaded, downloaded or cloned are the result. If you created `instances.txt`, a zip file or a clone only to try, you can remove them in CloudShell, for example:

```
rm instances.txt
```

## Common errors

| Symptom | Cause |
|---|---|
| Download does not work: *The download option is not supported in the Console Toolbar in this web browser* | CloudShell was opened in the toolbar at the bottom of the console. Use the link in the box, *Download from the AWS CloudShell console*, which opens CloudShell in a tab of its own. Make it a habit to always open CloudShell in its own tab. |
| The file is not found when downloading | Wrong path. Check with `ls` and `pwd` where the file is, and remember that relative paths count from the home folder. |
| The file is gone next time | It was outside the home folder, for example in `/tmp`. Only `/home/cloudshell-user` is kept. |
| None of your files show | You have probably changed region. Every region has its own home folder, so change back at the top right. |
| Large files are slow | Upload and download are slow for large files. Use an S3 bucket and `aws s3 cp` instead. |

## Files

This guide has no files.
