# Student Environment Setup

> Quick reference for getting your lab environment running. The instructor has pre-provisioned Azure resources needed for the labs. This guide walks you through the steps to connect to your resource environment after you RDP into your VM.

## What you've been given

Your instructor will provide you these values:

- **VM hostname or IP** — what you RDP to
- **VM login** — local Windows user (`lab_user{N}`) + password
- **Entra (Azure AD) login** — `lab_user{N}_<batch>@<tenant>` + temporary password

Inside Azure, you have your own **resource group** (`lab-dev{N}-<batch>`) and you are **Owner** on it. Nothing else in the subscription is yours; you won't see other students' resources.

Your RG contains:

- Cosmos DB serverless account
- Cosmos DB provisioned-autoscale account
- Azure AI Foundry account
  - Chat completions model (gpt-4.1-mini)
  - Embeddings model (text-embedding-3-small)
- Storage account
- Fabric capacity
- Lab VM with preloaded tools for executing labs

---

## First-time setup

### 1. RDP to the VM

Use the hostname/IP your instructor provided, with the VM admin login (`lab_user{N}` + VM password). This is a local Windows account, not your Entra login.

### 2. Sign in to Azure

Open the Terminal app with PowerShell on the VM and run:

```powershell
az login
```

Sign in with your **Entra credentials** (`lab_user{N}_<batch>@<tenant>` + temporary password). You'll be prompted to set a new password on this first sign-in — pick something you can remember; you'll use it again in Lab 1B and any time you reopen `az login`.

### 3. Populate workshop environment variables

From the workshop repo root:

```powershell
./SetEnv.ps1
```

This script auto-discovers your resource group, reads your Cosmos and Foundry endpoints from Azure, and writes them as User-scope environment variables. You should see output like:

```
Discovered resource group: lab-dev4-202606201430
Using resource group: lab-dev4-202606201430
...
Done.
  LAB_RESOURCE_GROUP          = lab-dev4-202606201430
  COSMOS_ENDPOINT             = https://cosmosl4xyz.documents.azure.com:443/
  COSMOS_ENDPOINT_PROVISIONED = https://cosmos-provisioned-l4xyz.documents.azure.com:443/
  FOUNDRY_ENDPOINT            = https://aifoundryl4xyz.services.ai.azure.com/
  EMBEDDINGS_ENDPOINT         = https://aifoundryl4xyz.cognitiveservices.azure.com/
  EMBEDDINGS_KEY              = ***
  COMPLETIONS_MODEL           = gpt41
  EMBEDDINGS_MODEL            = textembedding3small
```

> **Important:** User-scope env vars only show up in *new* processes. Close and reopen your PowerShell terminal and VS Code before the next step.

### 4. Confirm the env vars are visible

In a fresh terminal:

```powershell
$env:COSMOS_ENDPOINT, $env:FOUNDRY_ENDPOINT, $env:COMPLETIONS_MODEL
```

All three should print non-empty values. If any are blank, you skipped the terminal restart — close everything and try again.

### 5. Run the Lab 1B access script

The first lab introduces Azure RBAC by having you run the role-assignment commands yourself. From the repo root:

```powershell
cd 1B_SDK_CRUD/before
./1B_Account_Access.ps1
```

You should see:

```
Discovered accounts:
  Cosmos (serverless):  cosmosl4xyz
  Cosmos (provisioned): cosmos-provisioned-l4xyz
  Foundry:              aifoundryl4xyz
Cosmos DB Data Contributor role granted on cosmosl4xyz
Cosmos DB Data Contributor role granted on cosmos-provisioned-l4xyz
Cognitive Services Contributor role granted on aifoundryl4xyz
```

This grants **your Entra identity** the data-plane permissions needed for the SDK to read/write Cosmos and call Foundry. Even though you're Owner on the RG, those operations require separate data-plane RBAC permissions that are set by this script.

You're done. Open the first lab project in VS Code and start.

---

## Troubleshooting

What the scripts wire up:

- **SetEnv.ps1** reads your Azure resources and sets env vars. The labs read those env vars. If a lab can't find `$env:COSMOS_ENDPOINT`, the chain broke at SetEnv or at the terminal restart.
- **1B_Account_Access.ps1** grants your user the right to *use* Cosmos and Foundry at the data plane. Without it, the SDK gets `403 Forbidden` on the first call. Owner on the RG is *not* enough.
- Two separate auth modes are in play:
  - **Cosmos + Foundry chat** use **Entra ID** via `DefaultAzureCredential`. The SDK picks up your `az login` session.
  - **Embeddings (v1 endpoint)** still requires an **API key** (`EMBEDDINGS_KEY`). That's why SetEnv reads the key from Azure and stores it in an env var.


| Symptom | Most likely cause | Fix |
|---|---|---|
| `No active Azure CLI session. Run 'az login' first.` | You haven't signed into `az` yet | `az login` and sign in as your Entra lab user account |
| `No resource groups tagged project=cosmos-labs were found` | Wrong subscription is selected | `az account show` to see current sub; `az account set --subscription <id>` if needed |
| `Multiple lab resource groups found:` | You have access to more than one RG (instructor account, etc.) | Pick yours by number — match the `lab-dev{N}-...` to your student number |
| `$env:COSMOS_ENDPOINT` is blank after SetEnv ran | User env vars don't propagate to existing processes | Close *all* Terminal/PowerShell windows and VS Code, reopen, try again |
| Lab SDK call returns `403 Forbidden` on first read/write | Cosmos data-plane RBAC missing or still propagating | Run `1B_Account_Access.ps1`. If you just ran it, wait 1–3 minutes and retry — propagation isn't instant |
| Lab SDK call returns `401 Unauthorized` | Your `az login` token expired (more than an hour idle) | `az login` again in the terminal, then restart the lab process |
| Foundry chat returns `DeploymentNotFound` | `COMPLETIONS_MODEL` env var doesn't match the actual deployment | Re-run `./SetEnv.ps1` to read the deployment name directly from Azure |
| Embeddings call returns `401` | `EMBEDDINGS_KEY` missing or rotated | Re-run `./SetEnv.ps1` to pull the current key |

If something else goes wrong, the fastest way to recover is usually:

1. Re-run `./SetEnv.ps1`
2. Close and reopen your terminal / VS Code
3. Re-run `./1B_Account_Access.ps1`

The instructor has a roster with the canonical values your environment was provisioned with, and can compare.
