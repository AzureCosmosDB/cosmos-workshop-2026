---
title: Student Workshop Guide
description: Step-by-step student flow for connecting to the workshop VM, configuring Azure access, and completing each lab.
---

Follow this guide from top to bottom. Your trainer has already provisioned the
Azure resources and workshop VM.

## Your workshop journey

1. Get your credentials from the trainer.
2. Connect to the VM through Azure Bastion.
3. Sign in to Azure and configure the lab environment.
4. Choose C# or Python.
5. Complete the labs in order.
6. Notify the trainer when you finish.

## Step 1: Get your credentials

Your trainer sends you one row from the cohort roster. You need these values:

* `BastionUri`, the browser link to your VM
* `VmAdminUsername`, the local Windows username such as `lab_user3`
* `UserPrincipalName`, your Microsoft Entra username
* The shared password in `TempPassword` and `VmAdminPassword`

The portal and VM passwords are intentionally the same. You are not required to
change the password at first sign-in.

> [!IMPORTANT]
> Do not share your roster row, password, or Bastion link. Each student has a
> separate identity, VM, resource group, Cosmos DB accounts, and Foundry account.

Your resource group contains:

* One serverless Azure Cosmos DB account
* One provisioned-autoscale Azure Cosmos DB account
* One Azure AI Foundry account with chat and embedding model deployments
* One Windows workshop VM on a private virtual network
* Azure Bastion for browser-based VM access
* A Fabric workspace when the trainer includes Lab 4B

## Step 2: Connect to the workshop VM

1. Open the supplied `BastionUri` in a browser. An Azure Portal sign-in is not
   required for this link.
2. Enter `VmAdminUsername` and the shared password.
3. Select **Login** and wait for the Windows desktop.
4. Open PowerShell 7 from the Start menu.

The Bastion link contains no credentials. It opens an RDP session in the
browser, so you do not need a local RDP client.

## Step 3: Configure Azure access

### Sign in with your Entra account

Run:

```powershell
az login
```

Use `UserPrincipalName` and the same shared password used for the VM. Complete
any tenant-required authentication prompts.

Confirm that the expected subscription is selected:

```powershell
az account show --query "{subscription:name,user:user.name}" --output table
```

### Configure workshop environment variables

The repository is already cloned on the VM. Run:

```powershell
cd "$HOME\Documents\cosmos-workshop-2026"
./SetEnv.ps1
```

`SetEnv.ps1` discovers your resource group and writes the Cosmos DB endpoints,
Foundry endpoints, and model deployment names as user-scoped environment
variables.

Close every PowerShell and VS Code window, then reopen them. Existing processes
do not receive newly created user-scoped variables.

In a new PowerShell 7 window, verify the configuration:

```powershell
$env:LAB_RESOURCE_GROUP
$env:COSMOS_ENDPOINT
$env:COSMOS_ENDPOINT_PROVISIONED
$env:FOUNDRY_ENDPOINT
$env:EMBEDDINGS_ENDPOINT
$env:COMPLETIONS_MODEL
$env:EMBEDDINGS_MODEL
```

Every value should be non-empty.

### Apply data-plane access

From the repository root, run:

```powershell
cd 1B_SDK_CRUD/before
./1B_Account_Access.ps1
cd ../..
```

This grants your Entra identity the Cosmos DB and Foundry data-plane roles used
by the labs. Resource-group Owner access alone does not grant these data-plane
permissions. Allow one to three minutes for new role assignments to propagate.

## Step 4: Choose C# or Python

Use one language consistently unless the trainer asks you to compare both.

### C# workflow

1. Open the lab's `before/csharp` folder.
2. Read `Instructions.md`.
3. Complete the marked steps in the source files.
4. Run the project from that folder:

```powershell
dotnet run
```

### Python workflow

1. Open the notebook under the lab's `before/python` folder in VS Code.
2. Select the preconfigured Python kernel if prompted.
3. Read and run the cells in order.
4. Complete each exercise cell before moving forward.

The `before` folders are your exercises. Use the matching `after` folder only
to compare your result or recover when the trainer directs you to do so.

## Step 5: Complete the labs in order

| Order | Lab | C# instructions | Python notebook | Outcome |
|-------|-----|-----------------|-----------------|---------|
| 1 | 1B SDK CRUD | [Instructions](../1B_SDK_CRUD/before/csharp/Instructions.md) | [Notebook](../1B_SDK_CRUD/before/python/1B_SDK_CRUD.ipynb) | Create, read, update, and delete Cosmos DB items |
| 2 | 1D1 Query Language | [Instructions](../1D1_Query_Language/before/csharp/Instructions.md) | [Notebook](../1D1_Query_Language/before/python/1D1_Query_Language.ipynb) | Run parameterized and partition-aware queries |
| 3 | 1D2 Indexing | [Instructions](../1D2_Indexing/before/csharp/Instructions.md) | [Notebook](../1D2_Indexing/before/python/1D2_Indexing.ipynb) | Measure the impact of indexing policies |
| 4 | 1E Data Modeling | [Instructions](../1E_Data_Modeling/before/csharp/Instructions.md) | [Notebook](../1E_Data_Modeling/before/python/1E_Data_Modeling.ipynb) | Model data and partition keys around access patterns |
| 5 | 2C Completions and Embeddings | [Instructions](../2C_Completions_Embeddings/before/csharp/Instructions.md) | [Notebook](../2C_Completions_Embeddings/before/python/2C_Completions_Embeddings.ipynb) | Call chat and embedding models |
| 6 | 2D Vector Search | [Instructions](../2D_Vector_Search/before/csharp/Instructions.md) | [Notebook](../2D_Vector_Search/before/python/2D_Vector_Search.ipynb) | Store vectors and perform semantic search |
| 7 | 2E RAG Pipeline | [Instructions](../2E_RAG_Pipeline/before/csharp/Instructions.md) | [Notebook](../2E_RAG_Pipeline/before/python/2E_RAG_Pipeline.ipynb) | Build an end-to-end RAG pipeline |
| 8 | 2F Evaluation (optional) | [Instructions](../2F_Evaluation/before/csharp/Instructions.md) | [Notebook](../2F_Evaluation/before/python/2F_Evaluation.ipynb) | Score grounded responses with an LLM judge |
| 9 | 4A Chat Memory | [Instructions](../4A_Chat_Memory/before/csharp/Instructions.md) | [Notebook](../4A_Chat_Memory/before/python/4A_Chat_Memory.ipynb) | Persist multi-turn chat history in Cosmos DB |
| 10 | 4B Fabric Analytics (optional) | [Fabric instructions](../4B_Fabric_Mirror_Analytics/4B_Fabric_Mirror_Analytics_Instructions.md) | [Fabric instructions](../4B_Fabric_Mirror_Analytics/4B_Fabric_Mirror_Analytics_Instructions.md) | Mirror and analyze conversation history |

> [!IMPORTANT]
> Lab 2F uses data created by Lab 2E. Lab 4B uses conversation data created by
> Lab 4A and requires a Fabric workspace prepared by the trainer.

## Step 6: Finish your session

1. Save any notes or code changes required by the trainer.
2. Sign out of the Windows session.
3. Tell the trainer that your VM can be deallocated.
4. Do not delete Azure resources unless the trainer explicitly asks you to.

## Troubleshooting

| Symptom | Most likely cause | Fix |
|---------|-------------------|-----|
| `No active Azure CLI session` | Azure CLI is not signed in | Run `az login` with your Entra username and shared password |
| No workshop resource group is found | The wrong subscription is selected | Run `az account show`, then ask the trainer for the correct subscription if needed |
| Multiple workshop resource groups are shown | The signed-in identity can access more than one environment | Select the resource group matching the student number in your roster |
| An environment variable is blank | VS Code or PowerShell was open when `SetEnv.ps1` ran | Close all VS Code and terminal windows, reopen them, and check again |
| A Cosmos DB operation returns `403 Forbidden` | Data-plane RBAC is missing or still propagating | Run `1B_Account_Access.ps1`, wait up to three minutes, and retry |
| A Cosmos DB or Foundry call returns `401 Unauthorized` | The Azure CLI token expired | Run `az login` again and restart the lab process |
| Foundry returns `DeploymentNotFound` | The local model deployment names are stale | Run `SetEnv.ps1`, restart VS Code, and retry |
| A Python notebook cannot find a package | The wrong Python kernel is selected | Select the workshop Python interpreter and rerun the install cell |
| Lab 4B cannot access a workspace | Fabric was omitted or the workspace assignment is incomplete | Ask the trainer to verify the shared capacity and your workspace role |

All SDK labs authenticate with Microsoft Entra ID through `AzureCliCredential`.
No Cosmos DB or Foundry account key is required.

For most setup issues, use this recovery order:

1. Run `az login`.
2. Run `SetEnv.ps1` from the repository root.
3. Restart PowerShell and VS Code.
4. Run `1B_Account_Access.ps1` again.
5. Ask the trainer to compare your resource group and role assignments with the
   cohort roster.
