# 21 cfn-lint in VS Code

## What it is

cfn-lint is a tool that reads a CloudFormation template and finds errors before you send it to AWS. You install cfn-lint and its extension for VS Code, open a template with three deliberate errors and see how they are marked. Then you run the same check in a terminal and compare with `aws cloudformation validate-template`. Nothing is created in AWS.

## Why and when to use it

- **A typo in a template often only shows at deploy.** A template is just text. If you write `CidrBlok` instead of `CidrBlock`, the file looks reasonable, and the YAML syntax is correct.
- **By then the stack has already started.** Resources that were created before the error are removed again when the stack rolls back. A new stack that failed ends up in `ROLLBACK_COMPLETE` and must be deleted before you can try again with the same name.
- **Each such round takes minutes,** and much longer if the stack contains a database. Waiting for a database only to find a typo in a completely different resource is frustrating.
- **cfn-lint reads the file on your own computer** and compares each resource with AWS's description of which properties exist. It takes a few seconds, and the errors are shown with line and column so that you find them directly.

## How it works

- **cfn-lint is a Python program for the command line.** It is open source and needs no AWS account, since it does not talk to AWS at all. It only reads the file.
- **You install it with pip,** Python's package manager:

  ```
  pip install cfn-lint
  ```

- **cfn-lint knows which properties each resource type has,** which type the value should have and which properties are required. That is why it can say that `CidrBlok` is not a property of a VPC, or that a value that should be true or false is something else.
- **The extension for VS Code is called CloudFormation Linter.** It runs cfn-lint every time you save the file and draws red or yellow lines under what is wrong. The extension has no lint of its own: it needs cfn-lint to be installed already.
- **Each error has a rule code, a short text and a position with line and column.** You can search for the rule code if the text is unclear. Exactly how the line looks can differ a little between versions.

In this example, cfn-lint is used with the CloudFormation Linter extension. AWS's own extension, AWS Toolkit for VS Code, also has cfn-lint built in through the CloudFormation Language Server, and then no Python or pip is needed for the markings in VS Code. See [CloudFormation Language Server](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/ide-extension.html).

## Prerequisites

- [Python](https://www.python.org/) 3 on your computer, added to `PATH`.
- [VS Code](https://code.visualstudio.com/) on your computer, with the [CloudFormation Linter](https://marketplace.visualstudio.com/items?itemName=kddejong.vscode-cfn-lint) extension (installed in step 1).
- A terminal. On Windows, [Git Bash](https://git-scm.com/) or PowerShell.
- For the comparison with `validate-template`: the AWS CLI on your computer, signed in. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

No stack needs to exist, and nothing is created in AWS.

## Step by step

### 1. Install cfn-lint

1. Open a terminal and check that Python is there. It should answer with a version number, for example `Python 3` and something more:

   ```
   python --version
   ```

   If the command is not found, opens Microsoft Store or answers with an empty line, Python is not properly installed. Install it and tick the box that adds Python to `PATH`.

2. Install cfn-lint. This is done once per computer, not once per project:

   ```
   pip install cfn-lint
   ```

   If `pip` does not work, try running the same pip through Python:

   ```
   python -m pip install cfn-lint
   ```

3. Check that it worked. It should answer with a version number:

   ```
   cfn-lint --version
   ```

   If the command is not found, pip has put the program in a folder that is not in `PATH`, see Common errors.

4. Open VS Code, click **Extensions** in the row of icons on the far left and search for **CloudFormation Linter**. Check that the extension's id is `kddejong.vscode-cfn-lint` before you install, so that you get the right extension. It is not AWS that is shown as publisher, so look at the id and the number of installs before you click **Install**.

### 2. Three errors in a template

1. Put [broken-network-template.yaml](broken-network-template.yaml) in a folder on your computer. It only contains a VPC, a subnet, a route table and a route. At the top is a comment that says which three errors it contains.
2. Open the file in VS Code and save it with **Ctrl+S**. The extension runs cfn-lint when the file is saved, so it can take a couple of seconds before anything shows the first time.
3. Look at the lines that have got a line under them and hold the mouse over them. Then the error is shown with its rule code. The same errors are also in the panel **Problems** at the bottom of VS Code, with line numbers.

The three deliberate errors give four messages:

| Rule | Message | What is wrong |
|---|---|---|
| `E3014` | `Only one of ['CidrBlock', 'Ipv4IpamPoolId'] is a required property` | The VPC lacks `CidrBlock`, since it is misspelled. |
| `E3002` | `Additional properties are not allowed ('CidrBlok' was unexpected. Did you mean 'CidrBlock'?)` | `CidrBlok` is not a property of a VPC. |
| `E3012` | `'maybe' is not of type 'boolean'` | `MapPublicIpOnLaunch` must be `true` or `false`. |
| `E1020` | `'MyIgw' is not one of ['Vpc', 'PublicSubnet', ...]` | The route points at `MyIgw` with `!Ref`, but there is no resource with that name in the file. |

The misspelling gives two messages: one because the property does not exist, and one because the required `CidrBlock` is then missing. The messages above come from cfn-lint 1.61.0, run in November 2026. Newer versions can word them differently or use other rule codes.

Correct one error at a time, save and watch the marking disappear.

### 3. The same errors in a terminal

The same check works from the command line. That is useful when you are not in VS Code, and it is the same command that you can put in a script. [lint-template.sh](lint-template.sh) contains the commands in order.

1. Open a terminal and go with `cd` to the folder where `broken-network-template.yaml` is. Check with `ls` that it shows.
2. Run cfn-lint on the file:

   ```
   cfn-lint broken-network-template.yaml
   ```

   It prints the same errors that VS Code showed, one per message with rule code, text, file name, line and column. Then run it on a template of your own and see what it says. Warnings can appear even in a file that works.

3. Now ask AWS instead. `validate-template` sends the file to CloudFormation and asks for a check, but no stack is created. `file://` means that the AWS CLI should read a local file.

   ```
   aws cloudformation validate-template --template-body file://broken-network-template.yaml
   ```

   Look at what it answers and compare with the list from cfn-lint.

## Check the result

- VS Code marks the errors, and they show in **Problems**.
- `cfn-lint broken-network-template.yaml` prints the four messages.
- `validate-template` does not catch the misspelled `CidrBlok`.

## Clean up

Remove `broken-network-template.yaml` when you are done, so that it does not end up in a repository or get deployed by mistake.

## cfn-lint compared with validate-template

| `validate-template` | cfn-lint |
|---|---|
| Checks that the file is valid YAML or JSON, and that the template has a reasonable structure. | Checks that the properties exist, that the values have the right type, and that every `Ref` and `GetAtt` points at something in the file. |
| Does not catch misspelled properties like `CidrBlok`, since it does not compare the properties with what the resource type actually has. The error is found only at deploy. | Catches exactly the errors you make when you write templates by hand. |
| A request to AWS. Needs the AWS CLI signed in with the right permissions. | Runs entirely on your computer and needs no sign-in. |

Make cfn-lint a habit: save the file in VS Code, look for markings, and deploy only when the file is clean. It does not replace the test in AWS, but it removes the simplest errors before they cost time.

## Good to know

- **No errors in cfn-lint does not mean that the stack will work.** A clean file can still fail at deploy, for example if a CIDR collides with another subnet or if the account lacks a permission. cfn-lint finds errors in the file, not errors in the account.
- **If nothing is marked in a file,** make sure that the line `AWSTemplateFormatVersion` is at the top, as in the example file.

## Common errors

| Symptom | Cause |
|---|---|
| `pip` is not found | Python is not installed or not added to `PATH`. Run the Python installation again, tick the box for `PATH`, and restart the terminal. |
| `pip install` worked but `cfn-lint` is not found | pip has put the program in a folder for scripts that is not in `PATH`. pip usually prints a warning about it during the installation, with the folder's name. Add that folder to `PATH` and restart the terminal. |
| VS Code says that cfn-lint is not found | The extension does not find the program. Check that `cfn-lint --version` works in a terminal, then restart VS Code so that it reads `PATH` again. |
| Nothing is marked in the file | The extension does not recognise the file as a CloudFormation template. See Good to know. |

## Files

| File | What it is |
|---|---|
| `broken-network-template.yaml` | A short network template with three deliberate errors. Do not deploy it. |
| `lint-template.sh` | The commands in order: check the installation, lint the broken template and optionally your own, and run `validate-template`. |
