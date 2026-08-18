---
title: Trainer Environment Setup Guide
description: Provision, validate, and operate per-student Azure workshop environments.
---

> Covers the pre-class environment provisioning workflow built around [script/provision-student-environments.ps1](../script/provision-student-environments.ps1) and [bicep/main.bicep](../bicep/main.bicep).

1. [Deployment modes](#deployment-modes)
2. [What the script provisions](#what-the-script-provisions)
3. [Prerequisites](#environment-setup-prerequisites)
4. [Shared Fabric setup (batch mode, one-time)](#shared-fabric-setup-batch-mode-one-time)
5. [Running the provisioning script](#running-the-provisioning-script)
6. [Configuring per-student Fabric workspaces (batch mode)](#configuring-per-student-fabric-workspaces-batch-mode)
7. [Expected results](#expected-results)
8. [Handing out credentials](#handing-out-credentials)
9. [Smoke-testing one student environment](#smoke-testing-one-student-environment)
10. [Troubleshooting](#troubleshooting)
11. [Cost considerations](#cost-considerations)
12. [Cleanup](#cleanup)

---

## Deployment modes

The same Bicep tree supports two modes:

1. **Single-user test**
- When to use: Trainer validates a lab end-to-end before class
- Fabric handling: Disabled by default; add `-PerStudentFabric` only when validating Lab 4B
- Script invocation: `provision-student-environments.ps1 -StudentCount 1`

2. **Batch (shared Fabric SKU)**
  - When to use: Cohort provisioning
  - Fabric handling: One shared F-SKU in `lab-shared-fabric`; per-student deployments skip Fabric
  - Script invocation: `provision-shared-fabric.ps1` (once), then `provision-student-environments.ps1 -StudentCount N -SharedFabric`, then `configure-student-fabric.ps1`

Fabric is disabled by default. Use `-SharedFabric` for a cohort or
`-PerStudentFabric` for an isolated Lab 4B validation environment.

---

## What the script provisions

For each student, the script creates:

- **One Entra ID user**: `lab_user{N}_{batchId}@<tenant-default-domain>`, display name `{MMdd-HHmm} Lab User {N}` (the batch-time prefix groups all students from one class together when the Entra users blade is sorted by display name), with one randomly generated password shared by the portal and VM accounts. Password change at next sign-in is disabled so both credentials remain aligned.
- **One resource group**: `lab-dev{N}-{batchId}`, with the student granted **Owner** on that RG only (via [main.resources.bicep](../bicep/main.resources.bicep) `studentOwnerAssignment`). The student is also pre-granted **Cognitive Services Contributor** and **Cognitive Services OpenAI Contributor** on the Foundry account as a backstop against silent failures of the Lab 1B role grant — Owner alone does not include the OpenAI data actions, and the two-role pairing covers historical drift in which actions each role includes.
- **All workshop resources inside that RG**, deployed by [main.bicep](../bicep/main.bicep):
  - Cosmos DB serverless account (`cosmosl{N}<unique>`)
  - Cosmos DB provisioned-autoscale account with two containers (`OrdersHot`, `OrdersComposite`), each set to autoscale 100–1000 RU (`cosmos-provisioned-l{N}<unique>`)
  - Azure AI Foundry account with `gpt-5-mini` chat deployment and `text-embedding-3-small` embeddings (`aifoundryl{N}<unique>`)
  - Microsoft Fabric capacity, **F2 SKU per student** only with `-PerStudentFabric`. See [Cost considerations](#cost-considerations)
  - Lab VM (`Standard_D4ds_v7` by default, Windows, computer name `cosmos-lab{N}`) on a private VNet
  - Azure Bastion Standard with shareable links, a dedicated public IP, and `AzureBastionSubnet` for browser-based VM access without Azure Portal authentication
- **A roster CSV** at `out/students-{batchId}.csv` containing UPN, temp password, RG name, VM FQDN, VM admin user/password, and all account names.

Student number is used across multiple resources for easy visual confirmation, for example:
- VM admin user `lab_user{N}`
- Entra user `lab_user{N}_{batchId}@tenant`
- Resource group `lab-dev{N}-{batchId}`

---

## Environment Setup Prerequisites

| Requirement | Notes |
|---|---|
| Azure CLI with the `bicep` extension | `az bicep upgrade` if unsure |
| PowerShell 7+ | Scripts use PowerShell 7 syntax |
| Subscription **Contributor** + **User Access Administrator** | Create RGs and assign per-student Owner |
| Tenant **User Administrator** or **Global Administrator** | Create Entra users |
| **Fabric admin** with workspace-creation rights (batch mode only) | Required to run `configure-student-fabric.ps1`. Power BI Pro / Fabric Pro license plus tenant-setting **"Create workspaces"** enabled for your identity |
| Region quota in `-Location` | VM SKU, AI Foundry chat/embedding model TPM, and Fabric SKU all consume per-region quota |
| Time | Roughly 5-15 min per student (Fabric and Cosmos DB are slowest); script runs sequentially |

> Plan to provision at least 24 hours before class. Model deployments, role
> assignments, and Fabric capacity can take time to settle, and the trainer
> needs enough time to complete an end-to-end smoke test.

---

## Shared Fabric setup (batch mode, one-time)

Skip this section if you only run single-user test deployments.

Deploy one shared Fabric capacity per instructor (can persistent across multiple student groups and class sessions):

```powershell
./script/provision-shared-fabric.ps1
```

This deploys [bicep/shared.bicep](../bicep/shared.bicep) at subscription scope, creating resource group `lab-shared-fabric` and a Fabric capacity named `fabricworkshopshared` (default SKU **F2**). The deployment is idempotent — re-running against an existing capacity is a no-op.

F2 is the smallest paid Fabric SKU and is sufficient for the small mirror + T-SQL queries used in Lab 4B for any reasonable class size. If you observe throttling under unusually heavy concurrent use, scale up by editing `fabricSkuName` in [bicep/shared.bicepparam](../bicep/shared.bicepparam) (F4, F8) and re-running `provision-shared-fabric.ps1` to resize in place (supported by the Fabric provider and no student workspace re-assignment needed).

> Pause the shared capacity outside class hours from the Fabric admin portal (<https://app.fabric.microsoft.com/admin-portal/capacities>) to limit per-hour billing.

---

## Running the provisioning script

```powershell
az login
az account set --subscription "<workshop-subscription-id-or-name>"

# Single-user test (Fabric omitted)
./script/provision-student-environments.ps1 -StudentCount 1

# Isolated Lab 4B validation (per-student F2)
./script/provision-student-environments.ps1 -StudentCount 1 -PerStudentFabric

# Batch (per-student Fabric skipped; assumes shared capacity is already deployed)
./script/provision-student-environments.ps1 -StudentCount 12 -SharedFabric
```

### Parameters

| Param | Default | Notes |
|---|---|---|
| `-StudentCount` | required | 1–999 |
| `-SubscriptionId` | current `az` sub | Override to avoid relying on `az account` context |
| `-TenantDomain` | from `az account show --query tenantDefaultDomain` | Override if discovery fails or a custom verified domain is needed |
| `-Location` | `westus` | All current resource types are verified to deploy there |
| `-BicepparamFile` | `../bicep/main.bicepparam` | Fork for custom SKUs / model names |
| `-OutputDirectory` | `../out` | Roster CSV destination |
| `-SharedFabric` | off | Sets `deployFabric=false` per deployment; records shared capacity ID in the roster |
| `-PerStudentFabric` | off | Deploys one F2 capacity in each student resource group; use only for isolated Lab 4B validation |
| `-NoFabric` | off | Explicitly confirms that Fabric is omitted; omission is also the default |
| `-SharedFabricResourceGroup` | `lab-shared-fabric` | Override only if `provision-shared-fabric.ps1` used a non-default RG name |
| `-SharedFabricCapacityName` | `fabricworkshopshared` | Override only if `provision-shared-fabric.ps1` used a non-default capacity name |
| `-MaxParallelDeployments` | `5` | Number of student ARM deployments started concurrently; reduce if the subscription reaches regional quota or API throttling limits |

### What the script does, in order

1. Validates bicepparam path and output directory.
2. If `-SharedFabric`: looks up the shared capacity resource ID; throws if not found.
3. Resolves the tenant default domain.
4. Processes students in concurrent batches controlled by `-MaxParallelDeployments`. For each student N:
  1. Generates one Windows-complexity-compliant password for both the Entra user and VM admin account.
  2. Creates the Entra user with `--force-change-password-next-sign-in false`.
   3. Reads back the user's object ID.
   4. `az deployment sub what-if` against [main.bicep](../bicep/main.bicep) (validates parameters).
  5. Starts `az deployment sub create --no-wait` so other students in the batch can begin deploying. The script then waits for each deployment and retries failures up to **3 times with a 45-second backoff** between attempts. ARM deployments are idempotent, so a retry resumes from the current state rather than starting over. This handles the most common transient failure mode: an AI Foundry / Cognitive Services `RequestConflict` race where a child resource (project or model deployment) tries to attach to the account before its provisioning state has settled.
   6. Pulls deployment outputs and appends a roster row to `out/students-{batchId}.csv` (the row is flushed immediately, so a mid-batch failure still leaves a complete record of every student provisioned up to that point).
   7. Calls [Set-CosmosMirroringRbac.ps1](../script/Set-CosmosMirroringRbac.ps1) (a transliteration of the Microsoft-published [rbac-cosmos-mirror.sh](https://github.com/Azure-Samples/azure-cli-samples/blob/master/cosmosdb/common/rbac-cosmos-mirror.sh) bash sample) to grant the student a custom Cosmos role (`readMetadata` + `readAnalytics`) on the serverless account. Required for Lab 4B to configure Fabric mirroring via Entra ID auth. Uses `az` CLI — no extra auth context needed. Failures here are non-fatal — the script warns, records the student, and continues; a summary is printed at the end so you can re-run the helper manually.

Each batch is timestamped (`yyyyMMddHHmm`); re-runs produce a new `batchId` and never collide. Mid-loop failures leave orphan Entra users and RGs for the in-progress student only — see [Mid-run failure recovery](#mid-run-failure-recovery).

---

## Configuring per-student Fabric workspaces (batch mode)

Skip if you ran without `-SharedFabric`.

After `provision-student-environments.ps1` finishes, create one Fabric workspace per student:

```powershell
./script/configure-student-fabric.ps1 -RosterCsv ./out/students-202606201430.csv
```

For each row in the roster, this script:

1. Creates a Fabric workspace named `lab-ws-lab_user{N}-{batchId}` (idempotent — skipped if a workspace with that name already exists). The batch ID suffix prevents cross-cohort collisions on a shared capacity, where the generic student numbers (`lab_user1`, `lab_user2`, …) would otherwise let a second cohort silently adopt the first cohort's workspace and its content.
2. Assigns the workspace to the shared Fabric capacity.
3. Adds the student's Entra identity as workspace **Admin**.
4. Writes `FabricWorkspaceId` and `FabricWorkspaceName` back into the same roster CSV.

Parameters:

| Param | Default | Notes |
|---|---|---|
| `-RosterCsv` | required | Path to the roster produced by the provisioning script |
| `-CapacityDisplayName` | `fabricworkshopshared` | Match the name in `shared.bicepparam` if customized |
| `-WorkspaceNamePrefix` | `lab-ws` | Workspace name format is `<prefix>-<VmAdminUsername>-<BatchId>` |

The script logs warnings on per-student failures and continues; exit code is the failure count. Re-running is safe — successful workspaces are detected by name and only the role-assignment / capacity-assignment steps re-run.

> Students create the **Mirrored Cosmos DB** inside their workspace themselves as part of [Lab 4B](../4B_Fabric_Mirror_Analytics/4B_Fabric_Mirror_Analytics_Instructions.md), using their own Entra identity as the source-auth method. The setup script intentionally stops at workspace creation to preserve that teaching moment and avoid handling Cosmos keys.

---

## Expected results

A clean run prints something like:

```
Provisioning 12 student environment(s).
  Batch ID:      202606201430
  Tenant domain: contoso.onmicrosoft.com
  Location:      westus
  Fabric mode:   shared (fabricworkshopshared in lab-shared-fabric)

[Lab User 1] creating Entra user lab_user1_202606201430@contoso.onmicrosoft.com
[Lab User 1] running what-if for deployment lab-dev1-202606201430
[Lab User 1] deploying lab-dev1-202606201430 (attempt 1/3)
[Lab User 1] granting Cosmos mirroring RBAC on cosmosl1abc123def4
[Lab User 2] creating Entra user lab_user2_202606201430@contoso.onmicrosoft.com
...

Provisioned 12 student environment(s).
Roster written to: E:\...\out\students-202606201430.csv
```

### Per-student resource inventory

After a successful run, each `lab-dev{N}-{batchId}` resource group should contain:

| Resource type | Name pattern | Notes |
|---|---|---|
| Resource group | `lab-dev{N}-{batchId}` | Student is Owner |
| Cosmos DB (serverless) | `cosmosl{N}<unique>` | Used by labs 1B, 1D1, 1D2, 2*, 4A |
| Cosmos DB (provisioned) | `cosmos-provisioned-l{N}<unique>` | Used by lab 1E (partition-key metrics demo) |
| AI Foundry account | `aifoundryl{N}<unique>` | Hosts both chat (`gpt5mini`) and embedding (`textembedding3small`) deployments. Student is pre-granted **Cognitive Services Contributor** + **Cognitive Services OpenAI Contributor** on this account at provisioning. Lab 1B grants the same two roles again as a teaching exercise (the duplicate assignments are idempotent no-ops) |
| Fabric capacity | `fabricl{N}<unique>` | Created only with `-PerStudentFabric`. Omitted by default and under `-SharedFabric` |
| VNet / Subnet / NSG / PIP / NIC | per VM | Networking for the lab VM |
| Azure Bastion | `l{N}-bastion` | Standard SKU with a tokenized shareable link for browser-based VM access |
| VM | `lab-vm-l{N}-01` | Windows, `Standard_D4ds_v7`, computer name `cosmos-lab{N}`, admin `lab_user{N}` |

The `<unique>` suffix is a deterministic hash of the RG resource ID — same RG name yields the same suffix on re-deploys.

### Roster CSV columns

`out/students-{batchId}.csv` is the single artifact for credential distribution. Columns:

`Student, UserPrincipalName, TempPassword, ObjectId, ResourceGroup, VmName, VmComputerName, VmPublicIp, VmPublicFqdn, BastionName, BastionUri, VmAdminUsername, VmAdminPassword, CosmosServerlessAccount, CosmosProvisionedAccount, DocumentDbCluster, FoundryAccount, StorageAccount, EnvName, BatchId`

Batch mode appends: `FabricSharedCapacityId, FabricSharedCapacityName, FabricWorkspaceId, FabricWorkspaceName`. The last two are blank after `provision-student-environments.ps1` and are populated by `configure-student-fabric.ps1`.

> **CSV includes secrets.** `TempPassword` and `VmAdminPassword` contain the same password. Distribute the roster over a secure channel.

---

## Handing out credentials

Each student needs these values to start:

1. Their `BastionUri`, a tokenized shareable link that opens the VM connection page without an Azure Portal sign-in
2. VM login — `VmAdminUsername` + `VmAdminPassword`
3. Entra login (used inside the VM for Azure services) — `UserPrincipalName` + `TempPassword`
4. A pointer to [docs/StudentEnvironmentSetup.md](StudentEnvironmentSetup.md)

The Entra and VM accounts use the same generated password. Password change at
first sign-in is disabled so the credentials remain aligned. Tenant policy can
still require additional authentication enrollment when students run `az login`
or open Azure Portal.

---

## Smoke-testing one student environment

Before class, log in as one student end-to-end. Catches RBAC propagation lag, model deployment failures, and NSG issues that deployment success hides.

1. Open the student's `BastionUri` in a private browser window without signing in to Azure Portal. Use `lab_user{N}` and the VM admin password.
2. Open PowerShell 7 on the VM. Run:
   ```powershell
   az login
   ```
   Sign in as `lab_user{N}_{batchId}@<tenant>`. Change the password when prompted.
3. Change to the workshop repository cloned during VM initialization, then:
   ```powershell
  cd "$HOME\Documents\cosmos-workshop-2026"
   ./SetEnv.ps1
   ```
   Should auto-discover the student's RG and print non-empty values for all seven env vars. Restart the terminal.
4. Run the data-plane access script:
   ```powershell
   cd 1B_SDK_CRUD/before
   ./1B_Account_Access.ps1
   ```
   Should print "Discovered accounts: ..." and three "role granted" lines.
5. Open the Lab 1B C# or Python starter and run the first cell / `dotnet run`. If you get a 200 response on `read_item` / `create_item`, the environment is good.

> **Note:** Cosmos data-plane RBAC takes 1–3 minutes to propagate after `1B_Account_Access.ps1`. If the first SDK call returns 403, wait a minute and retry before assuming a real issue.

---

## Troubleshooting

### Provisioning script failures

| Symptom | Most likely cause | Fix |
|---|---|---|
| `Unable to determine the tenant default domain` | Service principal context, or `az account show` doesn't expose `tenantDefaultDomain` | Pass `-TenantDomain <verified-domain>` explicitly |
| `Failed to create Entra user … already exists` mid-loop | Previous failed run left orphan users with the same `batchId` (rare — only on script re-run with manually faked batch ID) | Delete the orphan user in Entra, or re-run the whole batch (new timestamp = new `batchId`) |
| `What-if failed` for a student | Quota or region issue — the deployment can't be planned | Check region quota for VM SKU, Foundry models, and Fabric F2 in your chosen `-Location` |
| `WARNING: ... deployment attempt 1 failed; waiting 45 s before retry` | Transient ARM failure on first attempt — most commonly an AI Foundry / Cognitive Services `RequestConflict` race. The script handles this automatically | None — let it retry. Successful retry produces an `attempt 2/3` line followed by the normal mirroring-RBAC step. No manual action needed |
| `Deployment '...' failed after 3 attempts` | The transient retry budget was exhausted. Usually means a non-transient problem: quota, capacity exhaustion, policy denial, or a regional outage | Inspect the latest deployment with `az deployment sub show --name <deploymentName> --query properties.error` and `az deployment operation group list --resource-group lab-dev{N}-{batchId} --name <inner> --query "[?properties.provisioningState=='Failed']"`. Resolve the underlying issue (request quota increase, change region, etc.) then [recover the failed student](#mid-run-failure-recovery) |
| Script hangs on what-if | Sub-scope what-if can take 1–2 minutes per deployment for the first student while bicep restores modules | Wait. Subsequent students are faster |
| `Forbidden` creating Entra user | Your identity lacks user-creation rights on the tenant | Get **User Administrator** at minimum, then re-run |
| `Forbidden` on `az deployment sub create` | Missing **Contributor** at subscription scope | Get Contributor + User Access Administrator |
| `Forbidden` on the per-student Owner role assignment | Missing **User Access Administrator** at subscription scope | Same as above |
| End-of-run warning: `Cosmos mirroring RBAC failed for N student(s)` | Transient `az cosmosdb sql role definition/assignment` failure during the RBAC step | Re-run `script/Set-CosmosMirroringRbac.ps1` for each affected student using the exact command printed in the warning. The deployment itself succeeded — only the mirroring role is missing |

### Mid-run failure recovery

The roster CSV is streamed row-by-row in deployment completion order. The script uses an exclusive append lock with retries, so `out/students-{batchId}.csv` retains every successfully provisioned student even when another process briefly reads the file or an earlier deployment in the batch is still running.

For the in-progress student N (and any not-yet-started students):

1. Delete the partial RG, if one was created: `az group delete --name lab-dev{N}-{batchId} --yes --no-wait`
2. Delete the partial Entra user, if one was created: `az ad user delete --id lab_user{N}_{batchId}@<tenant>`
3. Either re-run the whole script for a fresh batch (simpler audit trail; the partial roster from the failed run can be discarded), or top up just the missing students using the loop body from [provision-student-environments.ps1](../script/provision-student-environments.ps1) as a template and append rows to the existing roster by hand.

### Fabric workspace setup failures (batch mode)

`configure-student-fabric.ps1` logs warnings per student and continues; exit code = failure count.

| Symptom | Cause | Fix |
|---|---|---|
| `Failed to acquire a Fabric access token` | Not signed in, or account lacks Fabric API access | `az login`; confirm the account has a Fabric / Power BI Pro license |
| `Fabric capacity '...' not visible` | Capacity hasn't been registered with Fabric yet, or signed-in user lacks capacity-admin role | Wait 1–2 min after `provision-shared-fabric.ps1`; verify in the Fabric admin portal |
| `403 Forbidden` on `POST /workspaces` | Tenant setting restricts workspace creation to a specific security group | Get added to that group, or have a tenant admin grant the right |
| Workspace created but role assignment 403s | Student object ID stale or wrong | Verify `ObjectId` in roster matches the actual Entra user |

The script is idempotent — re-run for the same roster to retry failed rows. Successful workspaces are detected by name and only the capacity / role-assignment calls re-run.

### Deployment quota issues

- **VM SKU not available:** Change `vmSize` in [main.bicepparam](../bicep/main.bicepparam).
- **Foundry model quota exceeded:** Each student needs `gpt-5-mini` + `text-embedding-3-small` TPM. Default is 1 TPM each; large batches in one region exhaust quota. Request an increase or split across regions.
- **Fabric capacity quota:** Per-region F-SKU caps may block large shared capacities or many per-student F2s in single-user mode.

### Bicep param drift

The provisioning script overrides: `envName`, `location`, `resourceGroupName`, `vmAdminUsername`, `vmAdminPassword`, `vmComputerName`, `applyVmSecurityType=true`, `studentOwnerObjectId`, `tags`, and `deployFabric`. Everything else comes from [main.bicepparam](../bicep/main.bicepparam). Edit the parameter file to change SKUs or model names.

---

## Cost considerations

Cost Management recorded **INR 1,483.98 per fully active day** for the validated
`westus3` environment on August 15-16, 2026. The measured daily breakdown was:

| Service | Actual daily cost |
|---|---:|
| Azure Bastion Standard | INR 665.72 |
| VM compute (`Standard_D2ds_v7` in the measured deployment) | INR 585.38 |
| Virtual Network (private endpoints and public IPs) | INR 114.78 |
| VM OS disk | INR 55.29 |
| Cosmos DB | INR 55.09 |
| Private DNS | INR 7.71 |

The measured environment accumulated INR 5,004.18 from August 13-17. Contract
discounts, region, runtime, and model usage affect other subscriptions.

### Per-student resources (both modes)

| Resource | Cost shape | Per-student rough estimate |
|---|---|---|
| VM (`Standard_D4ds_v7`) | Per-hour when running; near zero when stopped and deallocated | Confirm current regional pricing with the Azure pricing calculator |
| Azure Bastion Standard | Fixed hourly charge while deployed, plus outbound data processing | Confirm current regional pricing with the Azure pricing calculator |
| Cosmos serverless | Per-request RU | Cents per student at lab volumes |
| Cosmos provisioned-autoscale (100–1000 RU × 2 containers) | Autoscale floor when idle, scales up under load | About \$9/mo per container at idle floor, up to \$88/mo per container at max. Realistic baseline of roughly \$18/mo per student total since most time is idle |
| AI Foundry S0 | Per-token | Cents per student per workshop |
| Public IP, private endpoints, DNS, bandwidth | Per-hour, per-zone, or per-GB | Included in the measured networking totals above |

### Fabric — varies by mode

| Mode | Rough cost | Notes |
|---|---|---|
| Single-user test (per-RG F2) | Around \$0.36/hr, about \$260/mo if left running | Only when validating; usually short-lived |
| Batch / shared F2 | Around \$0.36/hr, about \$260/mo shared across the cohort | One fixed charge regardless of student count |

In batch mode Fabric is a fixed cost rather than scaling with the cohort — a 12-student class pays the same shared F2 rate as a 1-student validation run, instead of 12× per-student F2s.

### Cost reduction

**Stop and deallocate VMs outside class hours.** A deallocated VM bills nothing for compute and disk storage cost is minimal.

```powershell
# Deallocate all student VMs for a batch
$batchId = '202606201430'
az vm list --query "[?tags.batch=='$batchId'].{rg:resourceGroup, name:name}" -o tsv |
  ForEach-Object {
    $parts = $_ -split "`t"
    az vm deallocate --resource-group $parts[0] --name $parts[1] --no-wait
  }

# Restart before class
az vm list --query "[?tags.batch=='$batchId'].{rg:resourceGroup, name:name}" -o tsv |
  ForEach-Object {
    $parts = $_ -split "`t"
    az vm start --resource-group $parts[0] --name $parts[1] --no-wait
  }
```

  **Bastion Developer cannot replace Standard in the current design.** Developer
  is free, but it is not available in `westus3`, supports only one VM connection
  at a time, and does not support the shareable links supplied in the student
  roster. It also cannot be reached by students without Azure Portal access. A
  larger cost optimization would use one shared Standard Bastion in a hub VNet
  peered to the student VNets; that requires a separate network topology change.

**Pause the shared Fabric capacity** from the Fabric admin portal when no class is in session. Pausing zeros per-hour billing without losing workspace state.

**Skip Fabric entirely** for batches that do not run Lab 4B. This is the default.
Use `-SharedFabric` for cohorts that run Lab 4B, and pause the shared capacity
outside class hours. Use `-PerStudentFabric` only for isolated validation.

The workshop no longer deploys an unused Storage account, Blob private endpoint,
or Blob private DNS zone. Based on the measured subscription rates, this removes
about INR 20.67 per active day from each new environment.

The provisioned Cosmos autoscale is already at the lowest allowed setting (100 RU floor × 2 containers). Deleting the RG between cohorts is the only way to zero those charges.

---

## Cleanup

Per-cohort cleanup (run after the workshop):

```powershell
$batchId = '202606201430'

# Delete all student RGs for the batch
az group list --query "[?tags.batch=='$batchId'].name" -o tsv | ForEach-Object { az group delete --name $_ --yes --no-wait }

# Delete all Entra users for the batch
az ad user list --query "[?contains(userPrincipalName, '_${batchId}@')].userPrincipalName" -o tsv | ForEach-Object { az ad user delete --id $_ }
```

Per-cohort Fabric workspace cleanup (batch mode): workspaces persist until manually deleted. Use the Fabric admin portal or the REST API (`DELETE /v1/workspaces/{id}`) — workspace IDs are in `FabricWorkspaceId` in the roster CSV.

**Do not delete** `lab-shared-fabric` resource group between cohorts. The shared capacity is designed to persist and be re-used across classes. Pause it instead from the Fabric admin portal.

The roster CSV is the cleanup source of truth — keep it until verified, then delete (contains secrets).
