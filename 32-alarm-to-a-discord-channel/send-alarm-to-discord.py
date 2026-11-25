# Sends CloudWatch alarm notifications from an SNS topic to a Discord channel.
# Paste into lambda_function.py and click Deploy.
#
# Configuration:
#   Environment variable: DISCORD_WEBHOOK_URL = the channel's webhook URL
#   (a secret, never put it in a repository)
#   Trigger: SNS, the topic your alarms send to
# No extra permissions: the role Lambda creates (write logs) is enough.
import json
import os
import urllib.request


def lambda_handler(event, context):
    for record in event["Records"]:
        sns = record["Sns"]
        try:
            # An alarm notification is JSON with the alarm's name, state and reason
            alarm = json.loads(sns["Message"])
            text = (f"**{alarm['NewStateValue']}**: {alarm['AlarmName']}\n"
                    f"{alarm.get('AlarmDescription') or ''}\n"
                    f"{alarm['NewStateReason']}")
        except (ValueError, KeyError):
            # Any other message on the topic is sent as it is
            text = sns.get("Subject") or sns["Message"]
        # Discord allows at most 2000 characters in content
        body = json.dumps({"content": text[:2000]}).encode()
        request = urllib.request.Request(
            os.environ["DISCORD_WEBHOOK_URL"], data=body, method="POST",
            # Send a User-Agent of our own instead of the default one
            headers={"Content-Type": "application/json", "User-Agent": "discord-alarm/1.0"})
        with urllib.request.urlopen(request, timeout=10) as answer:
            print("Discord answered", answer.status)
    return {"sent": len(event["Records"])}
