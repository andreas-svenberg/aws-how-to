# 25 Load test with ab

## What it is

A small and short HTTP load test against a load balancer with ab (ApacheBench), run from CloudShell. ab sends a set number of HTTP requests, several at a time, and measures how long the answers take. At the same time you follow the Auto Scaling group to see whether it reacts to the load.

## Why and when to use it

- Real visitors come through the load balancer with HTTP requests, which it shares out on the servers. Every request goes through the whole chain behind the load balancer.
- ab does exactly that: it sends a set number of requests, several at a time, and measures the response times.
- That gives numbers on how fast the site answers when many visit it at once, and whether any requests fail. It says more about how visitors experience the site than a CPU graph.
- You can also see whether the load is enough for CPU to go above the group's target. It is not certain in a short test, and that is also a result.

Use it to test how the site is experienced. To be sure of seeing [target tracking](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-target-tracking.html) scale out, a CPU load test on a server is simpler, see [Compare with a CPU load test](#compare-with-a-cpu-load-test).

## How it works

- ab comes with Apache's HTTP tools, and is installed with `dnf`.
- CloudShell is a Linux terminal in the console, with Amazon Linux 2023 and the AWS CLI installed. All users have `sudo`, so packages can be installed.
- What you install only stays while the session lives. Next time you open CloudShell, ab is gone and must be installed again. Only the home folder (`$HOME`) is kept between sessions.
- CloudShell itself costs nothing. What may cost is the servers, if the group scales out during the test.
- The two most important flags: `-n` is the total number of requests, `-c` how many are sent at the same time. With `-n 2000 -c 20`, two thousand requests are sent, twenty at a time.

## Prerequisites

- An Application Load Balancer, named for example `<prefix>-alb`, with a listener on HTTP port 80 that forwards to a target group with at least two healthy servers, and a site that answers on its address. See [Create an Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-application-load-balancer.html).
- An Auto Scaling group, named for example `<prefix>-web-asg`, with a target tracking policy on CPU, if you want to see whether the group scales out. See [Tutorial: Set up a scaled and load-balanced application](https://docs.aws.amazon.com/autoscaling/ec2/userguide/tutorial-ec2-auto-scaling-load-balancer.html).
- Access to CloudShell in the console.
- `PREFIX` set in CloudShell, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the CloudShell session you use for the steps below. Do it again if CloudShell has closed the session. See also [Before you start](../README.md#before-you-start) in the root README.

```
PREFIX=demo
```

### 1. Install ab

1. Open CloudShell with the icon in the console's top bar. Check that the region at the top right is the one where your load balancer is.
2. Ask `dnf` which package contains ab. That is better than guessing the package name.

   ```
   dnf provides /usr/bin/ab
   ```

   The answer is one or more package names. On Amazon Linux it is usually `httpd-tools`, but the answer here is what counts.

3. Install the package that `dnf provides` showed. If it showed another name, use that instead.

   ```
   sudo dnf install -y httpd-tools
   ```

4. Check that ab works. `-V` (capital V) prints the version.

   ```
   ab -V
   ```

### 2. Run the test

1. Open EC2 in a new browser tab, **Auto Scaling Groups**, and select your group. That is where you follow what happens during the test.
2. Back in CloudShell, get the load balancer's DNS name and check that the start page answers 200.

   ```
   ALB_DNS=$(aws elbv2 describe-load-balancers --names "${PREFIX}-alb" --query 'LoadBalancers[0].DNSName' --output text); echo "Load balancer: $ALB_DNS"
   ```

   If your load balancer has another name, use that name instead of `${PREFIX}-alb`.

   ```
   curl -s -o /dev/null -w "%{http_code}\n" "http://$ALB_DNS/"
   ```

3. Run ab against the start page:

   ```
   ab -n 2000 -c 20 "http://$ALB_DNS/"
   ```

   The slash at the end is not optional. Without it, ab answers with an error about an invalid URL and sends no requests at all.

4. While the test runs, look at the group's CPU (tab **Monitoring**) and at the tab **Activity**. CPU comes with a delay, so expect the graph to react after a few minutes. If the group starts another server, it shows up under Activity.
5. When ab is done, it prints a summary. See [Check the result](#check-the-result). Do not run the test many times in a row, one or two runs are enough.

[load-test-with-ab.sh](load-test-with-ab.sh) contains the same commands in order. Upload it to CloudShell (Actions, Upload file) if you prefer to run them from a file.

## Check the result

The summary from ab is long, but a few lines matter:

| Line | What it means |
|---|---|
| Requests per second | How many requests the site handled per second on average. The most used measure, the one to compare between runs. |
| Time per request | How long a request took. It is shown twice: first as one visitor experiences it, then on average over all concurrent requests. The first value is what a visitor experiences. |
| Failed requests | Should be zero. Otherwise ab shows in brackets what kind of error, for example Connect, Receive or Length. |
| Length (in Failed requests) | The answer had another length than the first one. On a dynamic page, it can be because the page varies a little, and then it is not a real error. |
| Non-2xx responses | Only shown if some answers did not have a status code in the 200 range. Check what the site answers with `curl -I` against the same address. |

Run the test once more with the same values and compare. If the group scaled out between the runs, the response time may have improved. That is exactly the effect scaling should have.

## Clean up

- If the group scaled out during the test, more servers are running, and they cost. Target tracking scales in again when the load is gone, but it takes a while. Check afterwards that the group is back at its normal number of servers:

  ```
  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${PREFIX}-web-asg" --query "AutoScalingGroups[0].[DesiredCapacity,length(Instances)]" --output text
  ```

  If your group has another name, use that name instead of `${PREFIX}-web-asg`.

- ab disappears by itself when the CloudShell session ends.

## Compare with a CPU load test

| A CPU load test on a server | ab through the load balancer |
|---|---|
| Loads the CPU of the server where it runs. The load ends up on one server, and no traffic goes through the load balancer. | Sends HTTP requests to the load balancer, which shares them out on all healthy servers. That is how real visitors load the site. |
| A safe way to trigger scaling, since CPU stays high as long as it runs. | Whether it triggers scaling depends on how heavy the page is and how big the test is. |
| Measures nothing about the visitors. | Tests the whole chain behind the load balancer, and gives numbers on response time and errors. |

A good way to work is to use both: the CPU test to test scaling, ab to test how the site is experienced.

A CPU test can be run on one of the servers, logged in with SSH. It starts two processes that keep the CPU busy for 15 minutes, and stops by itself:

```
for i in 1 2; do timeout 15m yes > /dev/null & done
```

It sends no traffic anywhere, it only uses the server's own CPU.

## Good to know

- **Keep the test small and short**, like the one here with 2000 requests and 20 at a time. The goal is to measure how the site answers, not to see how much it takes to bring it down.
- **Only test your own environment**, never someone else's site. According to AWS policy, load balancers and EC2 may be tested without prior approval, but denial of service (DoS) and flooding are prohibited. See [Penetration Testing](https://aws.amazon.com/security/penetration-testing/).
- **AWS has a separate policy for stress tests.** Before a bigger test, with much more traffic or over a long time, read it first and keep the level low until then. See [Amazon EC2 Testing Policy](https://aws.amazon.com/ec2/testing/).
- **CloudShell closes the session** after 20 to 30 minutes without keyboard or mouse. Then ab is gone too, and must be installed again.
- **ab running does not count as activity.** If you start a long test and walk away, the session can close in the middle of the test. Another reason to keep the test short.

## Common errors

| Symptom | Cause |
|---|---|
| ab answers with an error about an invalid URL and sends nothing | The slash at the end of the address is missing. |
| `ab: command not found` | The installation failed, or CloudShell has started a new session. Look at the answer from `dnf provides` again and install. |
| The group does not scale out | The test was too short or too small for CPU to stay above the target long enough. That is also a result. |
| Non-2xx responses in the summary | The site does not answer 200. Check with `curl -I` against the same address. |

## Files

| File | What it is |
|---|---|
| `load-test-with-ab.sh` | The commands in order: install ab, get the DNS name, check the start page, run the test. |
