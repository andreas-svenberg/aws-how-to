# 22 Stack termination protection

## What it is

With CloudFormation, a single command is enough to delete everything a stack has created, and for a stack with a database that means the database. Termination protection makes a stack impossible to delete until someone has first turned the protection off. You turn on the protection for a stack in the console and with the AWS CLI, try to delete the stack and read the error, and then compare with `DeletionPolicy` in the template. Nothing is deleted for real, but you always check that the protection is on before you try.

## Why and when to use it

- **`aws cloudformation delete-stack` removes every resource that the stack has created.** That is the whole point of a stack: everything belongs together and can be removed together. But it also applies to things you did not want to lose.
- **For a stack with a database, that means the database instance** and everything that belongs to it. What may be saved when the database is removed depends on what is in the template, see the comparison with `DeletionPolicy` below.
- **A script that deletes several stacks is convenient** when you want to clean up the account. But it does not ask for permission, and if you run it in the wrong terminal or the wrong account, everything disappears at once. That is exactly the kind of mistake the protection is for.
- **With termination protection turned on, CloudFormation refuses to delete the stack.** The deletion fails directly, and the stack and all its resources are unchanged. You must first turn off the protection, and that is a deliberate extra step.
- **The protection is a protection against mistakes, not against permissions.** Whoever has the right to change the protection can turn it off and then delete the stack. To stop a person completely, use IAM.

## How it works

Termination protection is just a flag on the stack, true or false. The rules:

- **The protection is off by default** for all new stacks.
- **It can be turned on when the stack is created, or afterwards** on a stack that already exists.
- **The flag can be changed whatever status the stack has,** even if an update has failed, except `DELETE_IN_PROGRESS` and `DELETE_COMPLETE`. When the deletion has already started, it is too late: the protection must be on before someone runs delete.
- **Whoever turns the protection on or off needs the permission `cloudformation:UpdateTerminationProtection`.** It is a permission you can leave out for a group that should only read.
- **Nested stacks, that is a stack that creates other stacks, inherit the protection from the outermost stack,** which is called the root stack.

See [Protect CloudFormation stacks from being deleted](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-protect-stacks.html).

## Prerequisites

- A CloudFormation stack, named for example `<prefix>-data`, in a finished status such as `CREATE_COMPLETE` or `UPDATE_COMPLETE`.
- The AWS CLI on your computer, signed in, or CloudShell. See [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
- `PREFIX` set in that terminal, see step 0 below and [Before you start](../README.md#before-you-start) in the root README.

If your stack has another name, use that name instead of `<prefix>-data`, and change `STACK` at the top of both scripts.

## Step by step

### 0. Set your prefix

Set the same prefix as in your resource names, in the terminal you use for the steps below. `export` makes the prefix visible also to scripts you run with `bash`, not only to commands you type in the terminal. Do it again if you open a new terminal. See also [Before you start](../README.md#before-you-start) in the root README.

```
export PREFIX=demo
```

### 1. Turn on in the console

1. Open CloudFormation and check the region at the top right. Choose **Stacks** in the menu on the left and click on the stack `<prefix>-data` so that it is selected.
2. Click **Stack actions** at the top right and choose **Edit termination protection**. A small dialog opens that shows whether the protection is on or off right now.
3. Choose **Enable** and click **Save**. The stack is not changed in any other way: no resources are touched and no update is run. Only the flag is changed.
4. Look at the stack's information in the console, where the protection should be shown as on. The reliable check is the AWS CLI in the next step.

When you create a new stack in the console, the same choice is under **Specify stack options** and **Advanced options**, where **Termination Protection** has the choice **Enable**. Then the stack is protected from the first second.

### 2. Turn on and check with the AWS CLI

The same thing with the AWS CLI. It is useful, since it can be put in a script directly after the stacks have been created. The commands are in [enable-termination-protection.sh](enable-termination-protection.sh).

1. Turn on the protection. If you already turned it on in the console, the command does no harm, it just sets the same value again:

   ```
   aws cloudformation update-termination-protection --enable-termination-protection --stack-name ${PREFIX}-data
   ```

   If you forget `--stack-name`, you get an error that the parameter is missing, and nothing is changed.

2. The command only answers with the `StackId`, the stack's full ARN. It says that the call went well, but not which value the flag has. Check it:

   ```
   aws cloudformation describe-stacks --stack-name ${PREFIX}-data --query 'Stacks[0].EnableTerminationProtection'
   ```

   It should answer `true`.

### 3. Try to delete the stack

This is the only scary moment in the guide, so take it calmly and check first. [try-to-delete-stack.sh](try-to-delete-stack.sh) checks the flag itself and stops if it is not true.

1. Run `delete-stack` **only** if `describe-stacks` just answered `true`. If it answered `false` or anything else, do not run the next command, since then the stack and everything it has created is deleted for real.

   ```
   aws cloudformation delete-stack --stack-name ${PREFIX}-data
   ```

   The command only takes one stack name, so no other stacks are affected by this call.

2. Read the answer. The command fails directly with an error that says the stack cannot be deleted while termination protection is enabled. The deletion never starts, so no resource in the stack is affected.
3. Check that the stack is unchanged, in the console or with:

   ```
   aws cloudformation describe-stacks --stack-name ${PREFIX}-data --query 'Stacks[0].StackStatus'
   ```

   The status should be the same as before, for example `CREATE_COMPLETE`.

Do not run a script that deletes several stacks to try it out. Depending on the order in which it deletes the stacks, other stacks may disappear before it stops at the protected one.

## Check the result

- `describe-stacks` answers `true` for `EnableTerminationProtection`.
- `delete-stack` fails with an error about termination protection.
- The stack's status is the same as before.

## Clean up

Termination protection is the result of this guide, and should stay on if you want the stack protected. If you only tried it out, or when you really want to delete the stack, turn it off with the same command as before, but with `--no-enable-termination-protection`:

```
aws cloudformation update-termination-protection --no-enable-termination-protection --stack-name ${PREFIX}-data
```

In the console, choose **Disable** in the same dialog as before.

## Termination protection compared with DeletionPolicy

Another protection is often confused with termination protection, namely `DeletionPolicy`. They solve different problems.

| Termination protection | DeletionPolicy |
|---|---|
| Applies to the whole stack, whatever resources it contains. | An attribute written on a single resource in the template. It says what CloudFormation should do with that resource when it is removed from the stack. |
| Stops `delete-stack` before anything happens: nothing is deleted, no status changes, and you get an error back directly. | Applies when the stack is actually deleted. The stack disappears, but the resource, or a snapshot of it, remains afterwards. It protects data, not the stack. |
| A flag on the stack that is turned on and off with a command. | Is in the template and follows the code. |

Two common values of `DeletionPolicy` are `Retain` and `Snapshot`. `Retain` means that the resource is left in the account although the stack is deleted. `Snapshot`, which works for databases among others, means that a snapshot is saved before the resource is removed. See [DeletionPolicy attribute](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-attribute-deletionpolicy.html).

The two complement each other.

## Good to know

- **Which stacks should be protected?** A reasonable rule of thumb is to protect what contains data that is hard to recreate, such as a stack with a database. A network or web servers can be rebuilt from the template in a few minutes, so there the protection may be more in the way than useful.
- **The protection only stops mistakes.** Whoever has the permission `cloudformation:UpdateTerminationProtection` can turn it off in a second. It is no replacement for giving the right permissions to the right group.
- **A script that deletes stacks is stopped the same way as `delete-stack`,** since it uses the same call. To delete the whole environment, turn off the protection first. That is not an error in the script, it is the point of the protection.
- **Always check the flag with `describe-stacks`** before you run `delete-stack` to try it out. It is easy to believe that the protection is on because you saw the dialog, but forgot to click **Save**.
- **The protection follows the stack, not the template.** If you create the stacks again from scratch, the new stacks have the protection turned off. It must be turned on every time a stack is created.
- **For a database instance in RDS, CloudFormation saves a snapshot by default** when the resource is deleted, if the template sets no `DeletionPolicy`. The snapshot stays and costs money until you remove it.

## Common errors

| Symptom | Cause |
|---|---|
| `delete-stack` deletes the stack | The protection was not on. Check the flag with `describe-stacks` first, every time. |
| A cleanup script stops at a stack | The stack has termination protection. Turn it off first if you really want to delete it. |
| Permission error when changing the protection | The user lacks `cloudformation:UpdateTerminationProtection`. |
| The protection cannot be turned on | The stack is in `DELETE_IN_PROGRESS` or `DELETE_COMPLETE`. It is too late. |

## Files

| File | What it is |
|---|---|
| `enable-termination-protection.sh` | Turns on termination protection for the stack and checks the flag. The command to turn it off is at the end. |
| `try-to-delete-stack.sh` | Checks that the protection is on, tries to delete the stack, and shows that its status is unchanged. Stops without deleting anything if the protection is off. |
