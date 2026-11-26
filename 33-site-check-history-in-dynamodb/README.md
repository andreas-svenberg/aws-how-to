# 33 Site check history in DynamoDB

## What it is

The site check from [guide 31](../31-site-check-with-lambda/) answers one question: does the site answer right now? This guide gives it a memory. Every check is saved as an item in an Amazon DynamoDB table, with the time, the result, the response time and the error message if the check failed. Afterwards you can ask the table when the site was down, and why. You create the table, give the function's role permission to write to it, replace the function's code, and read the history in the console and with the AWS CLI.

## Why and when to use it

- **CloudWatch keeps the metrics as points in a graph,** but not why a check failed. The error message is only in the function's log, spread out line by line.
- **A table keeps every check as an item of its own,** with all details in one place. Questions that come afterwards, such as "was the site down last night, and what was the error?", take a minute to answer.
- **DynamoDB has no server,** just like Lambda. There is nothing to choose a size for, start or update, and with on-demand you pay per read and write.
- **The function's role may only write new items to this one table.** Not read, not change other tables, not delete anything.

## How it works

- **A table is a collection of items, and an item is a collection of attributes.** Think rows and columns, but without a fixed schema: apart from the key, each item may have attributes of its own.
- **The primary key is decided when the table is created and cannot be changed afterwards.** Here it has two parts:
  - **Partition key `Site`:** the site's name, the same value as the function's `SITE_NAME`.
  - **Sort key `CheckedAt`:** the time of the check, as text in UTC, for example `2026-11-26T12:05:00Z`. The format always has the same length and starts with the year, so the text sorts in time order.
- **Partition key and sort key together identify an item.** Many items may have the same `Site`, as long as the time differs. Every check becomes a new item, and none is overwritten.
- **A query on the partition key returns the items sorted by the sort key.** The partition key must be given with an equality condition, and the order can be reversed to get the latest first.
- **Questions on other attributes than the key need a scan,** which reads the whole table. Here we only need "all checks for one site, in time order", which the key gives directly.
- **Key attributes can be String, Number or Binary,** and attribute names are case sensitive: `Site` is not the same as `site`.

See [Core components of Amazon DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html) and [Key condition expressions for the Query operation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.KeyConditionExpressions.html).

## Prerequisites

- The site check from [guide 31](../31-site-check-with-lambda/): the function `<prefix>-site-check` with its inline policy and its schedule in EventBridge.
- A user that may create DynamoDB tables and change IAM roles and Lambda functions, for example an administrator.
- The AWS CLI on your computer, signed in, or CloudShell. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

| Placeholder | What it is | Example |
|---|---|---|
| `<prefix>` | The prefix for your resource names, see the root README | `demo` |
| `<site-name>` | The site's short name, the value of `SITE_NAME` from guide 31 | `demo` |

## Step by step

### 1. Create the table

1. Open DynamoDB in the console, and **check the region at the top right**. It must be the same region as the function.
2. Choose **Tables** in the menu on the left, and click **Create table**.
3. Under **Table details**, set **Table name** to `<prefix>-site-check-history`.
4. **Partition key** is `Site`, type **String**. **Sort key** is `CheckedAt`, type **String**. Check the spelling: the key cannot be changed later.
5. Under **Table settings**, leave **Default settings**, and click **Create table**.
6. Wait until the table's status is **Active**.

The same from the AWS CLI:

```bash
aws dynamodb create-table --table-name $PREFIX-site-check-history --attribute-definitions AttributeName=Site,AttributeType=S AttributeName=CheckedAt,AttributeType=S --key-schema AttributeName=Site,KeyType=HASH AttributeName=CheckedAt,KeyType=RANGE --billing-mode PAY_PER_REQUEST
```

- `--attribute-definitions` names the two key attributes and gives their type, `S` for String. Only the key attributes are defined here, since the table has no fixed schema for the rest.
- `--key-schema` says which attribute is which part of the key: `HASH` is the partition key and `RANGE` is the sort key.
- `--billing-mode PAY_PER_REQUEST` is the on-demand mode, which AWS describes as the default and recommended mode. You pay per read and write request, and nothing for requests when the table is not used. There is no capacity to decide beforehand, and the table scales by itself. For a site check that writes one item every five minutes, that is the simplest choice. The other mode, provisioned, is described under [Good to know](#good-to-know).

### 2. Write and read an item by hand

Before the function writes to the table, write one item yourself, to see what an item looks like.

1. Click the table's name and **Explore table items**. The table is empty.
2. Click **Create item**. The two key attributes are already there. Set `Site` to `<site-name>`, and `CheckedAt` to the time now in UTC, in the format above.
3. Click **Add new attribute**, choose **Number**, name it `Ok` and give it the value `1`. Nobody decided beforehand that `Ok` should exist: that is what no fixed schema means.
4. Click **Create item**. The item shows under **Items returned**.

Write one more item from the AWS CLI. Replace `<site-name>`:

```bash
aws dynamodb put-item --table-name $PREFIX-site-check-history --item '{"Site": {"S": "<site-name>"}, "CheckedAt": {"S": "2026-11-26T12:05:00Z"}, "Ok": {"N": "0"}, "Error": {"S": "Test"}}'
```

`S` means String and `N` means Number. Numbers are also written within quotes. The command prints nothing when it succeeds. Back in the console, click **Run**: there are two items now, and only the new one has the attribute `Error`.

### 3. Give the function permission to write

1. Get the table's ARN:

   ```bash
   aws dynamodb describe-table --table-name $PREFIX-site-check-history --query Table.TableArn --output text
   ```

2. Open Lambda and the function `<prefix>-site-check`. Under **Configuration** and **Permissions**, the role's name is shown as a link. It opens the role in IAM.
3. Choose **Add permissions** and **Create inline policy**, and switch from the visual editor to **JSON**.
4. Paste the content of [site-check-history-policy.json](site-check-history-policy.json), and replace `REPLACE_WITH_TABLE_ARN` with the ARN from step 1. Keep the quotes around it.
5. Name the policy `<prefix>-site-check-dynamodb` and create it.

The policy allows one action, `dynamodb:PutItem`, on one table. The least possible permission.

### 4. Save every check

1. In the function, under the tab **Code**, replace everything in `lambda_function.py` with the content of [site-check-with-history.py](site-check-with-history.py), and click **Deploy**.

   The code does the same as in guide 31, and then writes one item with `Site`, `CheckedAt`, `Ok` and the response time `Ms`. If the check failed, the error message is added as `Error`. The metrics are sent before the item is written, so they reach CloudWatch even if the write fails.

2. Under **Configuration** and **Environment variables**, click **Edit** and **Add environment variable**. **Key** is `TABLE_NAME`, and **Value** is `<prefix>-site-check-history`. Click **Save**.

## Check the result

1. In the function, choose the tab **Test** and click **Test**. The response contains `"ok": 1` and the response time, as before.
2. In the table, under **Explore table items**, choose **Query**, enter `<site-name>` as **Partition key** and click **Run**. There is a new item with the time now.
3. The same from the AWS CLI, latest first. Replace `<site-name>`:

   ```bash
   aws dynamodb query --table-name $PREFIX-site-check-history --key-condition-expression "Site = :s" --expression-attribute-values '{":s": {"S": "<site-name>"}}' --no-scan-index-forward --query "Items[].[CheckedAt.S,Ok.N,Ms.N]" --output table
   ```

   `:s` is a placeholder for the value, and `--expression-attribute-values` says what it means. `--no-scan-index-forward` reverses the order. The items you wrote by hand have no response time, so that column is empty for them.

4. Run the query again after a while. The schedule from guide 31 adds a new item every five minutes.

## Clean up

Remove everything the guide created, when you no longer want the history:

1. In the function, put back the code from guide 31's [site-check.py](../31-site-check-with-lambda/site-check.py), and click **Deploy**. Otherwise every run fails when it tries to write to a table that no longer exists. Remove the environment variable `TABLE_NAME` too.
2. The inline policy `<prefix>-site-check-dynamodb` on the function's role, in IAM. If you remove the whole site check as in guide 31, the policy goes with the role.
3. The table: **Tables** in the menu on the left, select `<prefix>-site-check-history` and click **Delete**. All items are deleted, and it cannot be undone.

   ```bash
   aws dynamodb delete-table --table-name $PREFIX-site-check-history
   ```

## Good to know

- **DynamoDB has two capacity modes.** On-demand is the default: you pay per read and write request, and nothing for requests when the table is not used. In provisioned mode you decide the reads and writes per second beforehand, and pay per hour whether it is used or not. Storage is paid per GB and month in both. See [DynamoDB on-demand capacity mode](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/on-demand-capacity-mode.html).
- **The AWS Free Tier for DynamoDB uses provisioned capacity:** 25 read and 25 write capacity units and 25 GB of storage, per Region. See [Amazon DynamoDB pricing](https://aws.amazon.com/dynamodb/pricing/).
- **A check every five minutes is 12 items an hour,** a little under 9,000 a month, and each item is far smaller than the 1 KB that one write request unit covers.
- **New customers can earn AWS credits by creating a DynamoDB table,** as one of the activities under **Explore AWS** on the console's home page. See [Earning additional credits](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans-activities.html).

## Common errors

| Symptom | Cause |
|---|---|
| `AccessDeniedException` for `dynamodb:PutItem` in the test result or the log | The inline policy is missing on the role, or the ARN in it is not the table's ARN. Compare with the output of `describe-table`. |
| `ResourceNotFoundException` in the test result or the log | The table is in another region than the function, `TABLE_NAME` is misspelled, or the table has been deleted. |
| `ValidationException` about the key | The table's keys are not named exactly `Site` and `CheckedAt`, or are not of the type String. The key cannot be changed: delete the table and create it again. |
| `KeyError: 'TABLE_NAME'` | The environment variable `TABLE_NAME` is missing on the function. |
| The query returns nothing | The value after `:s` is not the same as the function's `SITE_NAME`. |

## Files

| File | What it is |
|---|---|
| `site-check-with-history.py` | The function's code: the site check from guide 31, which also saves every check. Paste it into `lambda_function.py`. |
| `site-check-history-policy.json` | The inline policy for the function's role: write items, only to the history table. |
