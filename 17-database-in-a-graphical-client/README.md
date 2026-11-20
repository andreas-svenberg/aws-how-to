# 17 Database in a graphical client

## What it is

A database in private subnets cannot be reached from the outside, and that is how it should be. Still, it is practical to be able to look at the tables in a window instead of in a terminal on a server. You start an SSH tunnel through the web server and connect a graphical database tool to your own computer. The traffic then goes through the tunnel to the database. I use [HeidiSQL](https://www.heidisql.com/) for this, but you can use another tool if you prefer, for example [MySQL Workbench](https://www.mysql.com/products/workbench/).

## Why and when to use it

- **The database is in private subnets.** Those subnets have no route to the internet gateway, so no traffic from the outside can come in there directly.
- **Public access is set to No on the database.** Its address only points to a private IP address inside the VPC, and it cannot be reached from your computer.
- **The database's security group only lets in port 3306 from the web server's security group.** Even if someone found a way into the network, the database would only answer servers that have the web server's security group.
- **Still, it is practical to browse the tables,** see what an application has saved and run a query, without typing everything in the `mariadb` client on the server. That is where a graphical tool helps.
- **An SSH tunnel through the web server solves it.** You open no new ports, change no security group and do not make the database public. Everything you use is already there: SSH to the web server, and the web server's right to reach the database.

## How it works

```
ssh -N -L 3306:<rds-endpoint>:3306 <prefix>-web
```

- **ssh listens on a port on your own computer,** the address `127.0.0.1`. Everything that connects to that port is taken care of by ssh instead of going out on the network.
- **ssh sends the traffic through the same encrypted connection** that you use when you log in to the web server. It is port 22, which the security group already lets in from your address, so no new rule is needed.
- **On the web server, the traffic is sent on to the database's address on port 3306.** To the database, it looks as if the connection comes from the web server, and the web server is allowed to connect.
- **`<rds-endpoint>` is the database's address from RDS,** the long address ending in `rds.amazonaws.com`. The name is resolved on the web server, inside the VPC, and therefore it becomes the private address.
- **`-L` means local port forwarding.** First comes the port on your computer, then the host that the web server should send to, and last the port on that host.
- **`-N` means that ssh should not start a shell on the server.** You get no prompt, the window just stands still. That is intended: you only want the tunnel, not to log in.

The same technique, through a bastion host to a web page, is described in [guide 13](../13-ssh-tunnel-through-a-bastion/).

## Prerequisites

- A MariaDB or MySQL database in Amazon RDS, in private subnets with **Public access** set to No, named for example `<prefix>-db`. Its security group lets in port 3306 from the web server's security group. See [Setting up public or private access in Amazon RDS](https://docs.aws.amazon.com/AmazonRDS/latest/gettingstartedguide/security-public-private.html).
- A web server in the same VPC, named for example `<prefix>-web`, that you can log in to with SSH through a block `Host <prefix>-web` in `~/.ssh/config`. Directly, or through a bastion host with `ProxyJump`.
- The database's user name and password.
- [HeidiSQL](https://www.heidisql.com/), or another database tool for MariaDB and MySQL, for example [MySQL Workbench](https://www.mysql.com/products/workbench/), on your computer.
- For the script: the AWS CLI on your computer, signed in. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your database or SSH host has another name, use that name instead of `<prefix>-db` and `<prefix>-web`, and change the settings at the top of `open-database-tunnel.sh`.

| Placeholder | What it is | Example |
|---|---|---|
| `<rds-endpoint>` | The database's address (RDS, Databases, the database, Endpoint) | `demo-db.abc123xyz.eu-north-1.rds.amazonaws.com` |
| `<db-user>` | The database's user name, chosen when the database was created | `admin` |

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Start the tunnel

[open-database-tunnel.sh](open-database-tunnel.sh) only contains the ssh command and a few checks, so you can just as well type the command by hand.

1. Open RDS in the console, choose **Databases** in the menu on the left and click on `<prefix>-db`. The database's **Endpoint** is shown there, copy it. If you leave out the address, the script fetches it itself with `aws rds describe-db-instances`.
2. Open a terminal in the folder where the script is. The script uses the host `<prefix>-web` from the file `config` in the folder `.ssh`. If you have no such entry, there is an example at the top of the script to paste.

   ```
   bash open-database-tunnel.sh <rds-endpoint>
   ```

   The script prints which port the tunnel listens on and where it goes, and then starts ssh with `-N` and `-L`.

3. Now nothing happens in the window, and that is right. No prompt comes, since you asked for `-N`. If you instead get an error message that the port is already in use, see Common errors.

The window must be open as long as you want to use the tunnel. If you close the terminal or press **Ctrl+C**, the tunnel disappears, and the database tool loses its connection.

With a bastion host, the entry for `<prefix>-web` points at the web server's private IP address and has `ProxyJump <prefix>-bastion`. Then the tunnel goes through the bastion to the web server and on to the database automatically, without you changing anything in the command.

### 2. Connect with HeidiSQL

Keep the tunnel window open during this whole step.

1. Download [HeidiSQL](https://www.heidisql.com/) and install it.
2. When HeidiSQL starts, the session manager is shown. Create a new session and choose the network type for MariaDB or MySQL over TCP/IP. That is the ordinary direct connection, and it is the one to use since the tunnel already exists.
3. As host, type `127.0.0.1`, that is your own computer, and port `3306`. Do not type the database's endpoint here. That address cannot be reached from your computer, which is the whole point of the tunnel.
4. The user is `<db-user>` and the password is the one chosen when the database was created. Click **Open**. If you get an error about denied access, the tunnel is usually right, but the password or the user is wrong.
5. The databases are shown on the left. Open the one you want to look at, and its tables are shown.

HeidiSQL is free (GPL), small and quick to install. MySQL Workbench is larger and has more functions than you need to look at a few tables. The tunnel works the same for both: connect to `127.0.0.1` with the same port, user and password.

HeidiSQL also has its own SSH tunnel function, which uses another program, plink. This guide lets ssh in the terminal handle the tunnel instead, the same ssh that you use to log in to the server.

## Check the result

- HeidiSQL is connected to `127.0.0.1` and shows the databases on the left.
- The tunnel window still stands still without a prompt.
- Nothing has been changed in AWS: no security group, no network ACL rule and no setting on the database. The database is as private as before.

## Clean up

Close the connection in HeidiSQL, and end the tunnel with **Ctrl+C** in the terminal window.

## Look at a table: WordPress as an example

If the database belongs to WordPress, the tables start with the prefix `wp_`, for example `wp_options`, `wp_users` and `wp_posts`.

- **Almost all content on the site is in `wp_posts`.** Not only posts, but also pages and attachments. An image uploaded in WordPress gets a row here with the type `attachment`, but the image file itself is stored elsewhere.
- **You can click on the table and see the rows,** but you can also write a query in the query window and run it. It is the same SQL as you would write in the `mariadb` client on the server:

  ```
  SELECT ID, post_title, post_type FROM wp_posts LIMIT 10;
  ```

  The query only picks three columns, so that the result is readable, and the first ten rows. Look at `post_type`, where you see `post`, `page`, `attachment` and maybe `revision` for saved versions.
- **Use the tool to read and understand.** If you change rows directly in the tables, WordPress can end up in a state that is hard to sort out. Make changes in the WordPress admin pages, not here.

## Good to know

- **The tunnel must end at the web server.** If you make the tunnel go to the bastion host and from there to the database, it times out, since the database's security group only lets in the web server's security group and not the bastion's.
- **Never show the database password in a screenshot.** Take the screenshot after you have connected, or hide the field. The same goes for the key in the pem file.

## Common errors

| Symptom | Cause |
|---|---|
| The port is already in use when the tunnel starts | MariaDB or MySQL is installed on your computer and listens on port 3306. Choose another local port, for example 3307: `bash open-database-tunnel.sh <rds-endpoint> 3307`, or `ssh -N -L 3307:<rds-endpoint>:3306 <prefix>-web`. Only the first number changes, the database still answers on 3306. Then type port 3307 in HeidiSQL. |
| Timeout through the bastion | The tunnel goes to the bastion instead of the web server. Let it end at `<prefix>-web`. |
| HeidiSQL loses the connection after a pause | The tunnel window has been closed, or the computer has gone to sleep. Check that the tunnel is still running. |
| Denied access in HeidiSQL | The tunnel is usually right, but the user name or the password is wrong. |

## Files

| File | What it is |
|---|---|
| `open-database-tunnel.sh` | Starts the SSH tunnel to the database through the web server, and fetches the database's address if it is left out. |
