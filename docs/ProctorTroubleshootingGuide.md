---
title: Proctor Troubleshooting Guide
description: Common issue-resolution and escalation guidance for proctors supporting the Azure Cosmos DB workshop
author: Workshop delivery team
ms.date: 2026-09-17
ms.topic: troubleshooting
keywords:
  - Azure Cosmos DB
  - proctor
  - troubleshooting
  - workshop
estimated_reading_time: 10
---

Use this guide while helping students during the workshop. Start with the quick
triage flow, then follow the matching issue playbook.

## Quick triage

1. Confirm the student's name or assigned student number.
2. Locate only that student in the approved Credentials workbook or cohort
   roster.
3. Confirm the `ResourceGroup`, `VmName`, `UserPrincipalName`, and `BastionUri`.
4. Ask for the exact error and the step that failed.
5. Check the VM power state before changing credentials or resources.
6. Follow the matching playbook below.
7. Escalate with the details in [Escalating an issue](#escalating-an-issue).

> [!IMPORTANT]
> Share only the affected student's credentials and use the approved secure
> channel. Never display or send the full Credentials workbook, another
> student's row, passwords, tokens, or full Bastion links in a group chat.

> [!WARNING]
> Students use `UserPrincipalName` and `TempPassword` for Windows and Azure.
> Never disclose or reset the hidden bootstrap VM administrator account.

## Registration and credentials

### Student cannot find the registration email

1. Verify the student's identity using the event's approved process.
2. Open the approved Credentials workbook or cohort roster.
3. Locate the row matching the student's name or assigned student number.
4. Share only these values through the approved secure channel:
   * `BastionUri`
   * `UserPrincipalName`
   * `TempPassword`
5. Ask the student to confirm receipt without repeating the password.

If no matching row exists, raise the issue in the proctor group. Do not assign
another student's environment.

### Student cannot sign in

1. Confirm that the complete `UserPrincipalName`, including the tenant domain,
   was entered.
2. Confirm that the student is using `TempPassword`.
3. Check that the student is not using a VM administrator name, a personal
   Microsoft account, or a work account.
4. Ask the student to type the password once to rule out spaces introduced by
   copying and pasting.
5. Check Caps Lock and the keyboard layout.
6. If the credentials still fail, escalate so the proctor group can check the
   Microsoft Entra user status and password.

Do not ask the student to post a password in chat or test it on a public screen
share.

### Student receives an authentication registration prompt

Tenant policy can require authentication registration.

1. Ask the student to complete the on-screen tenant prompts.
2. Confirm that the workshop `UserPrincipalName` is selected.
3. If registration requires an unavailable method or is blocked, capture the
   exact prompt and escalate.

## Bastion and VM access

### Bastion link does not open

First ask the student to copy the complete `BastionUri` into a private browser
window. Email and chat applications can truncate long links.

If the link is invalid or expired:

1. Open the student's `ResourceGroup` in the Azure portal.
2. Open the Azure Bastion resource.
3. Enter `shareable` in the resource menu search box.
4. Open **Shareable links**.
5. Locate the student's VM and create or regenerate its link.
6. Send the complete link only to that student through the approved secure
   channel.

If a link cannot be generated, capture the portal error and escalate.

### Bastion opens but cannot connect

1. Open the student's `ResourceGroup`.
2. Open the virtual machine identified by `VmName`.
3. Check **Status** on the VM Overview page.
4. If the VM is stopped or deallocated, select **Start**.
5. Wait until the status is **Running**, then wait another minute.
6. Ask the student to retry the Bastion link in a private browser window.
7. Capture and escalate the Bastion error if the connection still fails.

Do not redeploy, resize, delete, or recreate a VM unless the environment
administrator directs you to do so.

### Windows sign-in fails after Bastion connects

1. Confirm that the student is using `UserPrincipalName` and `TempPassword`.
2. Check that the student is not using VM administrator credentials instead of
   the user principal credentials.
3. Check Caps Lock, keyboard layout, and pasted spaces.
4. Confirm that the VM is **Running** and the Microsoft Entra user is enabled.
5. Escalate if sign-in still fails.

The Azure VM **Reset password** action resets a local VM account. It does not
reset a Microsoft Entra user's password.

> [!CAUTION]
> Use **Help > Reset password** only if the environment administrator confirms
> that the affected deployment uses a local student account. In that exception,
> open the student's VM, search for `reset password`, and paste the assigned
> local username and the same VM password from the Credentials workbook. Never
> reset or disclose the bootstrap administrator account.

### Bastion session is blank, frozen, or disconnected

1. Ask the student to close duplicate Bastion tabs.
2. Wait one minute and reconnect using the same link.
3. Retry in a private browser window.
4. Confirm that the VM remains **Running**.
5. Escalate immediately if several students are affected.

## Azure sign-in

### Student cannot run `az login`

1. Ask the student to open the integrated terminal in VS Code.
2. Confirm that the terminal profile is **PowerShell** or **PowerShell 7**.
3. Run:

```powershell
az login --use-device-code
```

4. Open <https://microsoft.com/devicelogin> in the visible browser.
5. Enter the displayed code and sign in with `UserPrincipalName` and
   `TempPassword`.
6. Verify the signed-in identity:

```powershell
az account show --query "{subscription:name,user:user.name}" --output table
```

If `az` is not recognized, close and reopen VS Code. If it remains unavailable,
escalate because VM initialization may be incomplete.

### Azure CLI uses the wrong account or subscription

Run:

```powershell
az logout
az account clear
az login --use-device-code
az account show --query "{subscription:name,user:user.name}" --output table
```

Ask the student to select the workshop account during device login. Escalate if
the expected subscription is not visible.

### Browser login window is hidden

Run `az login --use-device-code` from the VS Code terminal and ask the student
to open the device-login URL manually instead of waiting for a popup.

## Environment setup

### Student cannot run `.\setupENV`

The repository script is named `SetEnv.ps1`, not `setupENV`.

1. Open a PowerShell terminal in VS Code.
2. Run:

```powershell
cd "$HOME\Documents\cosmos-workshop-2026"
.\SetEnv.ps1
```

3. If the command reports no active Azure CLI session, run
   `az login --use-device-code` and retry.
4. If no workshop resource group is found, verify the signed-in account and
   subscription.
5. If the script still fails, capture the complete error and raise it in the
   proctor group.

Do not bypass PowerShell execution policy or modify `SetEnv.ps1` during the
workshop without approval.

### Repository or setup script is missing

1. Confirm that the student is using the assigned workshop VM.
2. Check for
   `$HOME\Documents\cosmos-workshop-2026\SetEnv.ps1`.
3. Open that repository folder in VS Code if it exists.
4. Escalate if the folder or script is missing because VM initialization may
   have failed.

Avoid cloning a second copy unless the proctor group directs you to do so.

### Environment variables are blank

1. Run `SetEnv.ps1` from the repository root.
2. Close every VS Code and PowerShell window.
3. Reopen VS Code and start a new PowerShell terminal.
4. Check:

```powershell
$env:LAB_RESOURCE_GROUP
$env:COSMOS_ENDPOINT
$env:COSMOS_ENDPOINT_PROVISIONED
$env:FOUNDRY_ENDPOINT
$env:EMBEDDINGS_ENDPOINT
$env:COMPLETIONS_MODEL
$env:EMBEDDINGS_MODEL
```

5. If any value remains blank, rerun `SetEnv.ps1` and escalate with its output.

### Multiple resource groups appear

Match the resource group to the student's `ResourceGroup` in the approved
roster. Never select another student's resource group.

## Azure Cosmos DB and Foundry access

### Student cannot see data in Azure Data Explorer

1. Confirm that the student opened a Cosmos DB account in their own
   `ResourceGroup`.
2. Allow one to three minutes for a new role assignment to propagate.
3. If portal Data Explorer remains unavailable, open VS Code.
4. Install or enable the official Azure Databases extension that provides Azure
   Cosmos DB support.
5. Sign in to the extension with the workshop `UserPrincipalName`.
6. Expand the student's subscription, Cosmos DB account, database, and
   container, then retry the query in VS Code.

If both the Azure portal and VS Code fail, follow the 401 or 403 playbook.

### Cosmos DB operation returns `403 Forbidden`

The student may have resource-group access without the required data-plane
role.

1. From the repository root, run:

```powershell
cd 1B_SDK_CRUD\before
.\1B_Account_Access.ps1
cd ..\..
```

2. Wait one to three minutes for role propagation.
3. Restart the lab process or notebook kernel and retry.
4. Escalate with the account name and complete error if it persists.

### Cosmos DB or Foundry returns `401 Unauthorized`

1. Run `az login --use-device-code`.
2. Confirm that `az account show` displays the workshop account.
3. Restart VS Code or the lab process to clear its cached token.
4. Retry once, then escalate if the refreshed login still returns 401.

### Cosmos DB or Foundry returns `429`

1. Stop repeatedly running the same cell or command.
2. Close duplicate notebooks or applications.
3. Wait 30 to 60 seconds and retry once.
4. Notify the proctor group if several students are affected.

## VS Code and lab execution

### Python notebook has no kernel or cannot import a package

1. Confirm that the student opened the lab's `before\python` folder.
2. Use **Select Kernel** and choose the preconfigured workshop interpreter.
3. Restart the kernel and run the cells from the beginning.
4. Run the lab's documented installation cell if one is provided.
5. Escalate if no Python interpreter is available.

### C# lab does not build or run

1. Confirm that the student opened the lab's `before\csharp` folder.
2. Run `dotnet --info` in the VS Code terminal.
3. Run `dotnet run` from the folder containing the project file.
4. Confirm that the student did not edit or open the matching `after` folder.
5. Capture the first build error and escalate if the SDK is missing.

### Lab returns `DeploymentNotFound`

1. Run `SetEnv.ps1` again from the repository root.
2. Close every VS Code and terminal window.
3. Reopen VS Code and retry.
4. Escalate with `COMPLETIONS_MODEL`, `EMBEDDINGS_MODEL`, and the Foundry
   account name if the error persists. Do not post secrets.

### Lab 4B cannot access Fabric

1. Confirm that Lab 4B is included in the session.
2. Confirm that the student is using the assigned Fabric workspace.
3. Ask the trainer to verify that Fabric capacity is active and the student's
   workspace role is assigned.
4. Escalate workspace or capacity errors.

## Standard recovery sequence

Use this sequence for authentication or configuration failures:

1. Run `az login --use-device-code`.
2. Confirm the workshop identity with `az account show`.
3. Run `SetEnv.ps1` from the repository root.
4. Close and reopen VS Code and PowerShell.
5. Run `1B_Account_Access.ps1`.
6. Wait one to three minutes.
7. Retry the failed step once.
8. Escalate if the issue persists.

Use the specific playbook instead for an invalid Bastion link, a stopped VM,
missing credentials, or a service-wide incident.

## Escalating an issue

Include:

* Student number or approved identifier
* Resource group and VM name
* Lab and step
* Exact error or a screenshot with credentials and tokens redacted
* VM power state
* Result of `az account show` with sensitive fields omitted
* Troubleshooting already attempted
* Whether one or multiple students are affected

Never include passwords, access tokens, full Bastion links, connection strings,
account keys, or the Credentials workbook.

Escalate immediately when:

* A roster row is missing or assigned to another student
* Microsoft Entra credentials remain invalid after basic checks
* `SetEnv.ps1` fails after the account and subscription are verified
* VM or repository initialization appears incomplete
* Resolution would require deleting, redeploying, resizing, or recreating a
  resource
* Multiple students report the same Azure service failure
* A security or privacy concern is suspected

## End-of-session checks

1. Ask students to save required work and sign out of Windows.
2. Record which VMs can be deallocated.
3. Have the environment administrator deallocate those VMs using the approved
   process.
4. Do not delete resource groups, users, or workspaces during class cleanup.
5. Remove credentials and screenshots from temporary proctor chats or local
   files according to the event's handling policy.

## Related guides

* [Student workshop guide](StudentEnvironmentSetup.md)
* [Trainer delivery guide](TrainerGuide.md)
* [Trainer environment setup](TrainerEnvironmentSetup.md)
* [Lab VM setup reference](LabVmSetup.md)
