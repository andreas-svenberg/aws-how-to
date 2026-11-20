# 26 Sticky sessions

## What it is

A load balancer normally sends each request to any healthy server. With stickiness, the same visitor is sent to the same server for a while. You turn on stickiness on the target group with a short duration, see in the browser and with `curl` that you stay on the same server, and turn it off again. You also see why you would rather not need it.

## Why and when to use it

- **The load balancer chooses a server for each request.** Two requests in a row from the same browser can end up on two different servers in two different zones, see [guide 23](../23-which-server-answers/).
- **Some applications save information about the visitor in the memory of the server** that received the request, for example a shopping cart or that the visitor is signed in. That information does not exist on the other server.
- **For such applications, the visitor must come back to the same server every time.** Otherwise the shopping cart or the sign-in disappears as soon as the load balancer chooses another server.
- **Stickiness solves it with a cookie.** The first time, the load balancer chooses a server and sends a cookie with the answer. The next time the browser sends the cookie back, the load balancer knows which server it should be.
- **But stickiness is usually a sticking plaster.** It hides that the servers are not interchangeable, instead of solving it, see the comparison below.

## How it works

- **Stickiness is an attribute on the target group, not on the load balancer itself.** If you have several target groups, they can have different settings.
- **Duration-based stickiness:** the load balancer creates a cookie of its own, and the visitor stays on the same server as long as the cookie is valid. The application does not need to know anything about it. In the attributes, the type is `lb_cookie`, and how long the cookie is valid is given in `stickiness.lb_cookie.duration_seconds`, in seconds. This is the one used in this guide.
- **Application-based stickiness:** the application's own cookie decides, for example a session cookie that the application already sets, and the load balancer follows it. In the attributes, the type is `app_cookie`, and you give the name of the application's cookie.
- **The duration can be from 1 second up to 7 days.** This guide uses one minute, so that you have time to see both that the visitor stays and that it lets go.

See [Edit target group attributes for your Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/edit-target-group-attributes.html).

## Prerequisites

- An Application Load Balancer named for example `<prefix>-alb`, with a target group named for example `<prefix>-web-tg` and at least two healthy servers, preferably in different Availability Zones.
- The page `which-server.php` from [guide 23](../23-which-server-answers/) on the servers' shared storage, so that you can see which server answers.
- The AWS CLI on your computer, signed in, or CloudShell. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your load balancer or target group has another name, use that name instead, and change the settings at the top of the scripts.

| Placeholder | What it is | Example |
|---|---|---|
| `<alb-dns>` | The load balancer's DNS name (EC2, Load Balancers, the load balancer) | `demo-alb-1234567890.eu-north-1.elb.amazonaws.com` |
| `<url-path>` | The path to the shared folder in the browser, as in guide 23 | `shared` |

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Turn on stickiness

In the console:

1. Go to EC2 and choose **Target Groups** under **Load Balancing** in the menu on the left.
2. Click on `<prefix>-web-tg` to open its details. On the tab **Attributes**, choose **Edit**.
3. Under **Target selection configuration**, select **Turn on stickiness**. Choose **Load balancer generated cookie** as **Stickiness type**, set **Stickiness duration** to one minute and choose **Save changes**.

Or the same thing with [set-stickiness.sh](set-stickiness.sh), which is also useful if you want to turn it on and off quickly:

```
bash set-stickiness.sh on
```

The script fetches the ARN of `<prefix>-web-tg` with `describe-target-groups` and then runs `aws elbv2 modify-target-group-attributes`. It sets three attributes: `stickiness.enabled` to `true`, `stickiness.type` to `lb_cookie` and `stickiness.lb_cookie.duration_seconds` to `60`. The answer is a table with all attributes, where you see that the change has gone through.

### 2. The browser stays

1. Open `http://<alb-dns>/<url-path>/which-server.php` in the browser. Without stickiness, the answer switches between the servers when you reload.
2. Reload the page several times with **F5**. Now the instance id and the zone should be the same every time. The browser sends the cookie back, and the load balancer sends you to the same server.
3. Press **F12** to open the developer tools. In Chrome and Edge, the tab is called **Application**, and there is **Cookies** in the list on the left with the load balancer's address. In Firefox, the tab is called **Storage**.
4. There you see the cookie that the load balancer has set, called `AWSALB`. The load balancer can also set `AWSALBCORS`, which is used for CORS. Look at the expiry time: it should be about one minute ahead, since you chose one minute.
5. Wait until the minute has passed and reload again. Now you can end up on the other server. It is not certain, since the load balancer chooses again and can choose the same server, but after a few tries you usually see the switch.

### 3. curl with and without cookie

With `curl` the difference shows clearly, since you decide yourself whether the cookie is sent.

1. Run `curl` without any cookie options, a few times in a row:

   ```
   curl -s http://<alb-dns>/<url-path>/which-server.php
   ```

   The answer still switches between the servers, although stickiness is on. That is because `curl` saves no cookies unless you ask it to. Every request is like a new visitor, and then the load balancer chooses freely.

2. Now ask `curl` to save the cookie and send it back, just as a browser does automatically. `-c cookies.txt` saves all cookies that the server sends in the file `cookies.txt`, and `-b cookies.txt` sends the ones that are in the file:

   ```
   curl -s -c cookies.txt -b cookies.txt http://<alb-dns>/<url-path>/which-server.php
   ```

   Run the command a few times, and the answer should stay on the same server.

3. [curl-with-and-without-cookie.sh](curl-with-and-without-cookie.sh) does both variants, six requests each, and finally prints the file with cookies. Open it first and change `PAGE_PATH` to the same path as in the browser. It looks up the DNS name of `<prefix>-alb` itself, or you give it as an argument:

   ```
   bash curl-with-and-without-cookie.sh
   ```

   The script removes `cookies.txt` when it is done.

## Check the result

- In the browser, the same server answers every time during the minute.
- `curl` without cookie switches between the servers, and `curl` with `-c` and `-b` stays on one.

## Clean up

Turn off stickiness, so that the target group is as it was:

```
bash set-stickiness.sh off
```

It sets `stickiness.enabled` to `false`. In the console, you do the same under **Attributes** for `<prefix>-web-tg`. Check with `curl` and `cookies.txt` that the answer switches between the servers again, and remove `cookies.txt` if you created it by hand in step 3.

## Stickiness compared with stateless servers

The goal of a load-balanced architecture is stateless servers. Everything that should remain is outside the servers, for example posts and users in a database, and uploaded files on shared storage.

- **When the servers are stateless, it does not matter which one answers.** All can answer all requests, and the load balancer can distribute freely.
- **With stickiness, the load becomes uneven.** A visitor who loads a lot stays on the same server, and new servers that an Auto Scaling group starts only get new visitors. Then scaling helps less.
- **If a server is removed,** at scale-in or because it became unhealthy, everything that only existed on that server disappears. All visitors who were bound to it lose their session.
- **If sign-in jumps,** so that you are signed out when you switch server, it is a sign that the servers are not identical. Something differs between them. That is what should be solved, so that the servers become interchangeable. Stickiness would only hide the problem, and it comes back as soon as a server is replaced.

## Good to know

- **Cookie names starting with `AWSALB`, `AWSALBAPP` or `AWSALBTG` are used by the load balancer itself,** for the different kinds of stickiness. They are reserved, so with application-based stickiness the application's cookie may not have a name starting that way. If you see those names in the browser, you know that the load balancer set them.
- **A long duration,** for example a day or seven days, keeps the visitor on the same server all that time. It makes the load even more uneven and the problems above bigger.

## Common errors

| Symptom | Cause |
|---|---|
| The answer still switches with `curl` although stickiness is on | `curl` forgets the cookie. Use `-c` and `-b`, or a browser. |
| The answer still switches in the browser | Stickiness is not saved, or the minute has passed. Check the target group's attributes. |
| *Target group ... not found* | The target group is not called `<prefix>-web-tg`. Change `TG_NAME` at the top of `set-stickiness.sh`. |
| `404` from `which-server.php` | The page is not on the shared storage, or `PAGE_PATH` is wrong. See guide 23. |

## Files

| File | What it is |
|---|---|
| `set-stickiness.sh` | Turns duration-based stickiness on (`on`, 60 seconds) or off (`off`) for the target group. |
| `curl-with-and-without-cookie.sh` | Six requests without cookie and six with, and prints the saved cookie. |
