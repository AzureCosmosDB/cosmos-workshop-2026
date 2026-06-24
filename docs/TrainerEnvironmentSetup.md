# Trainer Environment Setup Guide

> Covers the pre-class environment provisioning workflow built around [script/provision-student-environments.ps1](../script/provision-student-environments.ps1) and [bicep/main.bicep](../bicep/main.bicep).

1. [Deployment modes](#deployment-modes)
2. [What the script provisions](#what-the-script-provisions)
3. [Prerequisites](#prerequisites)
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
- Fabric handling: Per-RG F2 capacity (current bicepparam default)
- Script invocation: `provision-student-environments.ps1 -StudentCount 1`

2. **Batch (shared Fabric SKU)**
  - When to use: Cohort provisioning
  - Fabric handling: One shared F-SKU in `lab-shared-fabric`; per-student deployments skip Fabric
  - Script invocation: `provision-shared-fabric.ps1` (once), then `provision-student-environments.ps1 -StudentCount N -SharedFabric`, then `configure-student-fabric.ps1`

The bicepparam stays at `deployFabric = true` so single-user manual testing is unaffected. The `-SharedFabric` switch overrides that to `false` per deployment.

---

## What the script provisions

For each student, the script creates:

- **One Entra ID user**: `lab_user{N}_{batchId}@<tenant-default-domain>`, display name `{MMdd-HHmm} Lab User {N}` (the batch-time prefix groups all students from one class together when the Entra users blade is sorted by display name), with a randomly-generated temp password and "force change at next sign-in" set.
- **One resource group**: `lab-dev{N}-{batchId}`, with the student granted **Owner** on that RG only (via [main.resources.bicep](../bicep/main.resources.bicep) `studentOwnerAssignment`).
- **All workshop resources inside that RG**, deployed by [main.bicep](../bicep/main.bicep):
  - Cosmos DB serverless account (`cosmosl{N}<unique>`)
  - Cosmos DB provisioned-autoscale account with two containers (`OrdersHot`, `OrdersComposite`), each set to autoscale 100–1000 RU (`cosmos-provisioned-l{N}<unique>`)
  - Azure AI Foundry account with `gpt-4.1-mini` chat deployment and `text-embedding-3-small` embeddings (`aifoundryl{N}<unique>`)
  - Storage account (`stl{N}<unique>`)
  - Microsoft Fabric capacity, **F2 SKU per student** — only when `deployFabric=true` (default in single-user test mode; omitted in batch mode via `-SharedFabric`). See [Cost considerations](#cost-considerations)
  - Lab VM (`Standard_D4s_v3`, Windows, computer name `cosmos-lab{N}`) with public IP + NSG + VNet
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

> Plan to provision at least 24 hours before class. Model deployments and Fabric capacity can take that long to settle, and students need a window for their first-login password change.

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

# Single-user test (Fabric included)
./script/provision-student-environments.ps1 -StudentCount 1

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
| `-SharedFabricResourceGroup` | `lab-shared-fabric` | Override only if `provision-shared-fabric.ps1` used a non-default RG name |
| `-SharedFabricCapacityName` | `fabricworkshopshared` | Override only if `provision-shared-fabric.ps1` used a non-default capacity name |

### What the script does, in order

1. Validates bicepparam path and output directory.
2. If `-SharedFabric`: looks up the shared capacity resource ID; throws if not found.
3. Resolves the tenant default domain.
4. For each student N:
   1. Generates Windows-complexity-compliant passwords (student temp + VM admin).
   2. Creates the Entra user with `--force-change-password-next-sign-in true`.
   3. Reads back the user's object ID.
   4. `az deployment sub what-if` against [main.bicep](../bicep/main.bicep) (validates parameters).
   5. `az deployment sub create` — creates the RG, all resources, and grants the student Owner. Retries up to **3 times with a 45-second backoff** between attempts. ARM deployments are idempotent, so a retry resumes from the current state rather than starting over. This handles the most common transient failure mode: an AI Foundry / Cognitive Services `RequestConflict` race where a child resource (project or model deployment) tries to attach to the account before its provisioning state has settled.
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

1. Creates a Fabric workspace named `lab-ws-lab_user{N}` (idempotent — skipped if a workspace with that name already exists).
2. Assigns the workspace to the shared Fabric capacity.
3. Adds the student's Entra identity as workspace **Admin**.
4. Writes `FabricWorkspaceId` and `FabricWorkspaceName` back into the same roster CSV.

Parameters:

| Param | Default | Notes |
|---|---|---|
| `-RosterCsv` | required | Path to the roster produced by the provisioning script |
| `-CapacityDisplayName` | `fabricworkshopshared` | Match the name in `shared.bicepparam` if customized |
| `-WorkspaceNamePrefix` | `lab-ws` | Workspace name format is `<prefix>-<VmAdminUsername>` |

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
| AI Foundry account | `aifoundryl{N}<unique>` | Hosts both chat (`gpt41`) and embedding (`textembedding3small`) deployments |
| Storage account | `stl{N}<unique>` | General-purpose |
| Fabric capacity | `fabricl{N}<unique>` | **Single-user test mode only.** F2 SKU. Omitted under `-SharedFabric` |
| VNet / Subnet / NSG / PIP / NIC | per VM | Networking for the lab VM |
| VM | `lab-vm-l{N}-01` | Windows, computer name `cosmos-lab{N}`, admin `lab_user{N}` |

The `<unique>` suffix is a deterministic hash of the RG resource ID — same RG name yields the same suffix on re-deploys.

### Roster CSV columns

`out/students-{batchId}.csv` is the single artifact for credential distribution. Columns:

`Student, UserPrincipalName, TempPassword, ObjectId, ResourceGroup, VmName, VmComputerName, VmPublicIp, VmPublicFqdn, VmAdminUsername, VmAdminPassword, CosmosServerlessAccount, CosmosProvisionedAccount, FoundryAccount, StorageAccount, EnvName, BatchId`

Batch mode appends: `FabricSharedCapacityId, FabricSharedCapacityName, FabricWorkspaceId, FabricWorkspaceName`. The last two are blank after `provision-student-environments.ps1` and are populated by `configure-student-fabric.ps1`.

> **CSV includes secrets.** It contains two passwords per student. Distribute over a secure channel.

---

## Handing out credentials

Each student needs **four** values to start:

1. Their RDP target — `VmPublicFqdn` (or `VmPublicIp`)
2. VM login — `VmAdminUsername` + `VmAdminPassword`
3. Entra login (used inside the VM after RDP) — `UserPrincipalName` + `TempPassword`
4. A pointer to [docs/StudentEnvironmentSetup.md](StudentEnvironmentSetup.md)

The Entra temp password forces a change at first sign-in. Students should be aware they'll be prompted to pick a new password the first time they run `az login` or open the Azure Portal. In the browser they may also be required to set up additional authentication with an Authenticator app.

---

## Smoke-testing one student environment

Before class, log in as one student end-to-end. Catches RBAC propagation lag, model deployment failures, and NSG issues that deployment success hides.

1. RDP to the VM as `lab_user{N}` with the VM admin password.
2. Open PowerShell on the VM. Run:
   ```powershell
   az login
   ```
   Sign in as `lab_user{N}_{batchId}@<tenant>`. Change the password when prompted.
3. Clone or copy the workshop repo onto the VM, then:
   ```powershell
   cd <repo-root>
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

The roster CSV is streamed row-by-row as each student completes, so `out/students-{batchId}.csv` already contains every successfully-provisioned student up to the failure. Students 1..N-1 are usable as-is — their UPNs, passwords, RGs, and VM details are all in the CSV.

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
- **Foundry model quota exceeded:** Each student needs `gpt-4.1-mini` + `text-embedding-3-small` TPM. Default is 1 TPM each; large batches in one region exhaust quota. Request an increase or split across regions.
- **Fabric capacity quota:** Per-region F-SKU caps may block large shared capacities or many per-student F2s in single-user mode.

### Bicep param drift

The provisioning script overrides: `envName`, `location`, `resourceGroupName`, `vmAdminUsername`, `vmAdminPassword`, `vmComputerName`, `studentOwnerObjectId`, `tags`, and (in `-SharedFabric` mode) `deployFabric=false`. Everything else comes from [main.bicepparam](../bicep/main.bicepparam) — edit the param file to change SKUs or model names.

---

## Cost considerations

All figures below are rough planning estimates based on `westus` list prices. Confirm against the Azure pricing calculator before committing to a cohort budget.

### Per-student resources (both modes)

| Resource | Cost shape | Per-student rough estimate |
|---|---|---|
| VM (Standard_D4s_v3) | Per-hour when running; near zero when stopped & deallocated | About \$0.24/hr, or roughly \$170/mo if left running 24×7 |
| Cosmos serverless | Per-request RU | Cents per student at lab volumes |
| Cosmos provisioned-autoscale (100–1000 RU × 2 containers) | Autoscale floor when idle, scales up under load | About \$9/mo per container at idle floor, up to \$88/mo per container at max. Realistic baseline of roughly \$18/mo per student total since most time is idle |
| AI Foundry S0 | Per-token | Cents per student per workshop |
| Storage, Public IP, bandwidth | Per-GB or per-hour | Negligible |

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

**Pause the shared Fabric capacity** from the Fabric admin portal when no class is in session. Pausing zeros per-hour billing without losing workspace state.

**Skip Fabric entirely** for batches that don't run Part 3 / Lab 4B: set `deployFabric = false` in [main.bicepparam](../bicep/main.bicepparam) (single-user) or skip `provision-shared-fabric.ps1` and run without `-SharedFabric` (batch).

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
