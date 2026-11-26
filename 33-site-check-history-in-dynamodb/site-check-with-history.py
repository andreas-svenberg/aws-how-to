# site-check-with-history.py
# The site check from guide 31, which also saves every check as an item in a DynamoDB table.
# Asks a website like a visitor, sends two metrics to CloudWatch, Available (1 or 0) and
# ResponseTimeMs, and writes one item with the time, the result and any error message.
# Paste into lambda_function.py and click Deploy.
#
# Configuration (as in guide 31, plus TABLE_NAME):
#   Timeout 20 seconds (General configuration)
#   Environment variables:
#     SITE_URL   = the full address to check, for example http://<alb-dns>/
#     SITE_NAME  = a short name for the site, used as the dimension Site and the partition key
#     TABLE_NAME = the table's name, for example <prefix>-site-check-history
#   Trigger: EventBridge, schedule expression rate(5 minutes)
#
# The function's role needs the inline policy from guide 31 (site-check-policy.json)
# and the inline policy in site-check-history-policy.json.
import os
import time
import urllib.request
from datetime import datetime, timezone

import boto3

NAMESPACE = "SiteCheck"   # must match the condition in guide 31's site-check-policy.json

cloudwatch = boto3.client("cloudwatch")
dynamodb = boto3.client("dynamodb")


def lambda_handler(event, context):
    url = os.environ["SITE_URL"]
    error = None
    start = time.time()
    try:
        with urllib.request.urlopen(url, timeout=10) as answer:
            ok = 1 if answer.status == 200 else 0
    except Exception as e:
        print("Check failed:", e)
        error = str(e)
        ok = 0
    ms = (time.time() - start) * 1000
    site = [{"Name": "Site", "Value": os.environ["SITE_NAME"]}]
    cloudwatch.put_metric_data(Namespace=NAMESPACE, MetricData=[
        {"MetricName": "Available", "Dimensions": site, "Value": ok, "Unit": "Count"},
        {"MetricName": "ResponseTimeMs", "Dimensions": site, "Value": ms, "Unit": "Milliseconds"},
    ])

    # Save the check as one item. CheckedAt is the time in UTC, so the items sort by time.
    item = {
        "Site": {"S": os.environ["SITE_NAME"]},
        "CheckedAt": {"S": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")},
        "Ok": {"N": str(ok)},
        "Ms": {"N": str(round(ms))},
    }
    if error:
        item["Error"] = {"S": error}
    dynamodb.put_item(TableName=os.environ["TABLE_NAME"], Item=item)

    print(f"{url} ok={ok} {ms:.0f} ms")
    return {"ok": ok, "ms": round(ms)}
