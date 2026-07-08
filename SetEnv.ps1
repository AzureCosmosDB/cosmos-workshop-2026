# Workshop Environment Setup
# Run on the lab VM after `az login`. Discovers the student's lab resource group
# and all required endpoints/keys, then writes them to User-scope env vars used
# by every lab in this repo. Restart VS Code or the terminal after running.
#
#   ./SetEnv.ps1                       # auto-discover the RG (works for student logins)
#   ./SetEnv.ps1 -ResourceGroup <name> # specify explicitly (instructor / multi-RG)

param(
  [Parameter(Mandatory = $false)]
  [string]$ResourceGroup
)

$ErrorActionPreference = 'Stop'

# ---- Require an active az session ----
az account show -o none 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Error "No active Azure CLI session. Run 'az login' first."
  exit 1
}

# ---- Discover the lab resource group ----
if (-not $ResourceGroup) {
  Write-Output "Discovering lab resource group..."
  $rgListJson = az group list --query "[?tags.project=='cosmos-labs'].name" -o json
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to list resource groups. Pass -ResourceGroup explicitly."
    exit 1
  }
  $candidates = @($rgListJson | ConvertFrom-Json)

  if ($candidates.Count -eq 0) {
    Write-Error "No resource groups tagged project=cosmos-labs were found. Pass -ResourceGroup explicitly."
    exit 1
  } elseif ($candidates.Count -eq 1) {
    $ResourceGroup = $candidates[0]
    Write-Output "Discovered resource group: $ResourceGroup"
  } else {
    Write-Output "Multiple lab resource groups found:"
    for ($i = 0; $i -lt $candidates.Count; $i++) {
      Write-Output ("  [{0}] {1}" -f $i, $candidates[$i])
    }
    $selection = Read-Host "Select resource group [0-$($candidates.Count - 1)]"
    if (-not ($selection -match '^\d+$') -or [int]$selection -lt 0 -or [int]$selection -ge $candidates.Count) {
      Write-Error "Invalid selection."
      exit 1
    }
    $ResourceGroup = $candidates[[int]$selection]
  }
}

Write-Output "Using resource group: $ResourceGroup"

# ---- Cosmos DB (serverless + provisioned, distinguished by capability) ----
$cosmosJson = az cosmosdb list -g $ResourceGroup -o json
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to list Cosmos accounts in $ResourceGroup."; exit 1 }
$cosmosAccounts = @($cosmosJson | ConvertFrom-Json)

$COSMOS_ENDPOINT = $null
$COSMOS_ENDPOINT_PROVISIONED = $null
foreach ($acct in $cosmosAccounts) {
  $isServerless = $false
  if ($acct.capabilities) {
    $isServerless = [bool]($acct.capabilities | Where-Object { $_.name -eq 'EnableServerless' })
  }
  if ($isServerless) {
    $COSMOS_ENDPOINT = $acct.documentEndpoint
  } else {
    $COSMOS_ENDPOINT_PROVISIONED = $acct.documentEndpoint
  }
}
if (-not $COSMOS_ENDPOINT) { Write-Error "No serverless Cosmos account found in $ResourceGroup."; exit 1 }
if (-not $COSMOS_ENDPOINT_PROVISIONED) { Write-Error "No provisioned Cosmos account found in $ResourceGroup."; exit 1 }

# ---- Azure AI Foundry (single AIServices account hosts both chat and embeddings) ----
$foundryJson = az cognitiveservices account list -g $ResourceGroup -o json
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to list Cognitive Services accounts in $ResourceGroup."; exit 1 }
$foundry = @($foundryJson | ConvertFrom-Json) | Where-Object { $_.kind -eq 'AIServices' } | Select-Object -First 1
if (-not $foundry) { Write-Error "No AIServices (Foundry) account found in $ResourceGroup."; exit 1 }
$foundryName = $foundry.name

# Foundry chat completions use the *.services.ai.azure.com host (Entra ID auth).
$FOUNDRY_ENDPOINT = "https://$foundryName.services.ai.azure.com/"
# v1 embeddings still need the *.cognitiveservices.azure.com host with key auth.
$EMBEDDINGS_ENDPOINT = $foundry.properties.endpoint

$EMBEDDINGS_KEY = (az cognitiveservices account keys list -g $ResourceGroup -n $foundryName --query key1 -o tsv).Trim()
if ($LASTEXITCODE -ne 0 -or -not $EMBEDDINGS_KEY) { Write-Error "Failed to read keys for $foundryName."; exit 1 }

# ---- Model deployment names (the names used in API calls, not raw model names) ----
$deploymentsJson = az cognitiveservices account deployment list -g $ResourceGroup -n $foundryName -o json
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to list model deployments for $foundryName."; exit 1 }
$deployments = @($deploymentsJson | ConvertFrom-Json)

$completion = $deployments | Where-Object { $_.properties.model.name -notmatch 'embedding' } | Select-Object -First 1
$embedding  = $deployments | Where-Object { $_.properties.model.name -match  'embedding' } | Select-Object -First 1
if (-not $completion) { Write-Error "No chat completion deployment found on $foundryName."; exit 1 }
if (-not $embedding)  { Write-Error "No embedding deployment found on $foundryName."; exit 1 }
$COMPLETIONS_MODEL = $completion.name
$EMBEDDINGS_MODEL  = $embedding.name

# ---- Persist as User-scope environment variables ----
[System.Environment]::SetEnvironmentVariable('LAB_RESOURCE_GROUP',         $ResourceGroup,               'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT',            $COSMOS_ENDPOINT,             'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT_PROVISIONED',$COSMOS_ENDPOINT_PROVISIONED, 'User')
[System.Environment]::SetEnvironmentVariable('FOUNDRY_ENDPOINT',           $FOUNDRY_ENDPOINT,            'User')
[System.Environment]::SetEnvironmentVariable('EMBEDDINGS_ENDPOINT',        $EMBEDDINGS_ENDPOINT,         'User')
[System.Environment]::SetEnvironmentVariable('EMBEDDINGS_KEY',             $EMBEDDINGS_KEY,              'User')
[System.Environment]::SetEnvironmentVariable('COMPLETIONS_MODEL',          $COMPLETIONS_MODEL,           'User')
[System.Environment]::SetEnvironmentVariable('EMBEDDINGS_MODEL',           $EMBEDDINGS_MODEL,            'User')

Write-Output ""
Write-Output "Done."
Write-Output "  LAB_RESOURCE_GROUP          = $ResourceGroup"
Write-Output "  COSMOS_ENDPOINT             = $COSMOS_ENDPOINT"
Write-Output "  COSMOS_ENDPOINT_PROVISIONED = $COSMOS_ENDPOINT_PROVISIONED"
Write-Output "  FOUNDRY_ENDPOINT            = $FOUNDRY_ENDPOINT"
Write-Output "  EMBEDDINGS_ENDPOINT         = $EMBEDDINGS_ENDPOINT"
Write-Output "  EMBEDDINGS_KEY              = ***"
Write-Output "  COMPLETIONS_MODEL           = $COMPLETIONS_MODEL"
Write-Output "  EMBEDDINGS_MODEL            = $EMBEDDINGS_MODEL"
Write-Output "Restart VS Code / your terminal to pick up the new environment variables."
