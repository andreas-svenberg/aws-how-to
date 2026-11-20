# site-check.py
# Asks a website like a visitor and sends two metrics to CloudWatch:
# Available (1 or 0) and ResponseTimeMs. Paste into lambda_function.py and click Deploy.
#
# Configuration:
#   Timeout 20 seconds (General configuration)
#   Environment variables:
#     SITE_URL  = the full address to check, for example http://<alb-dns>/
#     SITE_NAME = a short name for the site, used as the dimension Site
#   Trigger: EventBridge, schedule expression rate(5 minutes)
#
# The function's role needs the inline policy in site-check-policy.json.
import os
import time
import urllib.request

import boto3

NAMESPACE = "SiteCheck"   # must match the condition in site-check-policy.json

cloudwatch = boto3.client("cloudwatch")


def lambda_handler(event, context):
    url = os.environ["SITE_URL"]
    start = time.time()
    try:
        with urllib.request.urlopen(url, timeout=10) as answer:
            ok = 1 if answer.status == 200 else 0
    except Exception as error:
        print("Check failed:", error)
        ok = 0
    ms = (time.time() - start) * 1000
    site = [{"Name": "Site", "Value": os.environ["SITE_NAME"]}]
    cloudwatch.put_metric_data(Namespace=NAMESPACE, MetricData=[
        {"MetricName": "Available", "Dimensions": site, "Value": ok, "Unit": "Count"},
        {"MetricName": "ResponseTimeMs", "Dimensions": site, "Value": ms, "Unit": "Milliseconds"},
    ])
    print(f"{url} ok={ok} {ms:.0f} ms")
    return {"ok": ok, "ms": round(ms)}
