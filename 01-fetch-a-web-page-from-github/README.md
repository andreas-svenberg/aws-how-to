# 01 Fetch a web page from GitHub

## What it is

A web server on an EC2 instance fetches its page directly from a public GitHub repository with `curl`, instead of you writing the page in the terminal. First by hand on the server, then automatically with user data, so that a new server shows the right page without anyone logging in.

## Why and when to use it

- **The repository becomes the source.** You change the page in the repository on your computer, not on the server. The server only fetches what is already finished. A change made on the server only exists there, and it disappears when the server is replaced.
- **Every change is in the history**, with who made it and when. If something went wrong, you can see which commit changed the page and go back to a version that worked.
- **The same file ends up on every server that fetches it.** Several web servers behind a load balancer must show the same page, and that is easy when they all fetch from the same address.
- **A new server can get the right page at once** when it starts, with the same line in user data.
- **No code is typed by hand in the terminal.** A quote in the wrong place in an `echo` command gives a broken page, and that error is rarely found on the first try.

Use `curl` for a single file. For a page with several files, for example images and CSS, see [Alternative: git clone](#alternative-git-clone).

## How it works

- When you click a file on github.com, you get a whole web page around the code, with menu, line numbers and buttons. If the server fetches that address, it gets GitHub's page, not your file.
- The **raw address** gives only the content of the file:

  ```
  https://raw.githubusercontent.com/<account>/<repo>/main/<path>
  ```

  You do not need to write it yourself. Open the file on github.com and click **Raw**. The address in the browser is the one to use.
- It only works for **public repositories**, since the server is not signed in to GitHub. A private repository answers `404 Not Found`, not "access denied", so it looks as if the file does not exist.
- Because the repository is public, **no secrets may be in it**: no key files, passwords or access keys.

## Prerequisites

- A public GitHub repository with the page you want to show, for example [index.html](index.html) from this folder.
- An EC2 instance running Amazon Linux 2023, with a public IP address and a security group that allows SSH (port 22) from your IP address and HTTP (port 80). See [Get started with Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html).
- Apache installed and running on the instance. See [Tutorial: Install a LAMP server on AL2023](https://docs.aws.amazon.com/linux/al2023/ug/ec2-lamp-amazon-linux-2023.html).
- The key file for the instance's key pair.

| Placeholder | What it is | Example |
|---|---|---|
| `<account>` | Your GitHub account name (github.com, top right) | `my-account` |
| `<repo>` | The repository's name | `my-site` |
| `<path>` | The path to the file in the repository | `web/index.html` |
| `<key>` | The name of your key file, without `.pem` (on your computer) | `my-key` |
| `<public-ip>` | The instance's public IPv4 address (EC2, Instances, the instance) | `203.0.113.10` |

## Step by step

### 1. Get the raw address

1. Open the file on github.com and click **Raw**.
2. Copy the address from the browser's address bar. It starts with `raw.githubusercontent.com`.

### 2. Fetch the page to the server

1. Connect to the instance with SSH:

   ```
   ssh -i ~/.ssh/<key>.pem ec2-user@<public-ip>
   ```

2. Fetch the file with `curl` and write it to Apache's folder. `sudo` is needed because the folder is owned by root.

   ```
   sudo curl -fsSL -o /var/www/html/index.html "https://raw.githubusercontent.com/<account>/<repo>/main/<path>"
   ```

   `-o` names the file to write. `-f` makes curl stop on an error instead of saving the error message as the page. `-s` and `-S` make it quiet except for errors. `-L` follows redirects.

3. Check what ended up in the file. You should see your HTML with the `meta charset` line. If it says something else, curl has fetched the wrong thing.

   ```
   head /var/www/html/index.html
   ```

4. Reload `http://<public-ip>` in the browser. The page from the repository is shown.

### 3. Change the page and fetch it again

1. Change the file in the repository.
2. On the server, run exactly the same `curl` command again (arrow up). It overwrites the old file with the new one.
3. Reload the page in the browser.

Still the old page? GitHub sends raw files with a cache of 300 seconds, so it can take up to five minutes before a new version is fetched. Wait a while and run `curl` again.

### 4. Let the server fetch the page itself (user data)

The `curl` line works the same in user data, the script that runs when an instance starts for the first time. [user-data.sh](user-data.sh) installs Apache, starts it and fetches the page. User data runs as root, so `sudo` is not needed.

1. Open `user-data.sh` and replace the address in `RAW_URL` with your raw address. The address is in one place at the top, so you only change it there.
2. Paste the script under **Advanced details, User data** when you launch a new instance.
3. When the instance is running, open its public IP address in the browser.

The result is a server that shows the right page without anyone having logged in to it. A new instance with the same user data gets the same page, and if you change the page in the repository, the next server gets the new version.

## Alternative: git clone

`curl` fetches one file at a time. git fetches the whole repository, and then everything in the folder comes along, also images and other files that the page uses.

1. Install git once:

   ```
   sudo dnf install -y git
   ```

2. Clone the repository to the home folder, with its normal https address ending in `.git`. Public repositories are cloned without signing in, so no keys need to be on the server.

   ```
   git clone https://github.com/<account>/<repo>.git
   ```

3. Copy the page to Apache's folder. The web server only reads what is in `/var/www/html`.

   ```
   sudo cp ~/<repo>/<path> /var/www/html/
   ```

4. Next time, go into the folder, fetch the new version and copy again:

   ```
   cd ~/<repo> && git pull
   ```

This suits a page made of several files. For a single `index.html`, `curl` is simpler, since nothing needs to be installed.

## Check the result

- The browser shows your page at `http://<public-ip>`.
- `head /var/www/html/index.html` on the server shows your HTML.
- For a server started with user data: if the page does not show, read the log on the server:

  ```
  sudo cat /var/log/cloud-init-output.log
  ```

## Clean up

The page fetched to `/var/www/html/index.html` is the result, so there is nothing to remove. If you used git clone, you can remove the copy of the repository in the home folder:

```
rm -rf ~/<repo>
```

If you launched an instance in step 4 only to test user data, terminate it: EC2, Instances, select the instance, **Instance state, Terminate instance**.

## Common errors

| Symptom | Cause |
|---|---|
| `404 Not Found` | GitHub does not find the file. Check the account, the repository's name, that the branch is called `main` and that the path is right, with upper and lower case. A private repository also answers 404, not a message about access. |
| The browser only shows `404: Not Found` | The flag `-f` is missing, so curl saved the error message as if it were the page. The error is in the address, not in Apache. |
| `Permission denied` | curl may not write in `/var/www/html`. The folder is owned by root, so the command needs `sudo`. In user data it is not needed, everything runs as root there. |
| The server shows GitHub's menu and buttons | The address contains `blob`, it is the one you see when you click the file on github.com. Always use the address from the **Raw** button. |
| Strange characters instead of å, ä and ö | The line `<meta charset="utf-8">` is missing in the file. Add it to the file in the repository and fetch again. |

## Files

| File | What it is |
|---|---|
| `index.html` | A minimal page to put in your repository. |
| `user-data.sh` | User data that installs Apache and fetches the page at first boot. Change the address in `RAW_URL`. |
