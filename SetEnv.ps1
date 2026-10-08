# Workshop Environment Setup
# Run on the lab VM after `az login`. Discovers the student's lab resource group
# and all required endpoints, then writes them to User-scope env vars used
# by every lab in this repo. Restart VS Code or the terminal after running.
#
#   ./SetEnv.ps1                       # auto-discover the RG (works for student logins)
#   ./SetEnv.ps1 -ResourceGroup <name> # specify explicitly (instructor / multi-RG)

param(
  [Parameter(Mandatory = $false)]
  [string]$ResourceGroup
)

$ErrorActionPreference = 'Stop'

function Get-CosmosAccountEndpoint {
  param(
    [Parameter(Mandatory = $true)][string]$ResourceGroupName,
    [Parameter(Mandatory = $true)][psobject]$Account,
    [Parameter(Mandatory = $false)][ValidateRange(1, 10)][int]$MaxAttempts = 6
  )

  if (-not [string]::IsNullOrWhiteSpace([string]$Account.documentEndpoint)) {
    return [string]$Account.documentEndpoint
  }

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $endpoint = (
      az cosmosdb show `
        --resource-group $ResourceGroupName `
        --name $Account.name `
        --query documentEndpoint `
        --output tsv `
        --only-show-errors
    ).Trim()
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($endpoint)) {
      return $endpoint
    }
    if ($attempt -lt $MaxAttempts) {
      Start-Sleep -Seconds 10
    }
  }
  return $null
}

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

# ---- Cosmos DB (serverless + provisioned, distinguished by stable name) ----
$cosmosAccounts = @()
for ($attempt = 1; $attempt -le 6; $attempt++) {
  $cosmosJson = az cosmosdb list -g $ResourceGroup -o json --only-show-errors
  if ($LASTEXITCODE -eq 0) {
    $cosmosAccounts = @($cosmosJson | ConvertFrom-Json)
    if ($cosmosAccounts.Count -ge 2) { break }
  }
  if ($attempt -lt 6) {
    Start-Sleep -Seconds 10
  }
}
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to list Cosmos accounts in $ResourceGroup."; exit 1 }

$serverlessAccount = $cosmosAccounts |
  Where-Object { $_.name -notlike 'cosmos-provisioned-*' } |
  Select-Object -First 1
$provisionedAccount = $cosmosAccounts |
  Where-Object { $_.name -like 'cosmos-provisioned-*' } |
  Select-Object -First 1
$discoveredAccountNames = ($cosmosAccounts | ForEach-Object name) -join ', '
if (-not $serverlessAccount) {
  Write-Error "No serverless Cosmos account found in $ResourceGroup. Discovered: $discoveredAccountNames"
  exit 1
}
if (-not $provisionedAccount) {
  Write-Error "No provisioned Cosmos account found in $ResourceGroup. Discovered: $discoveredAccountNames"
  exit 1
}

$COSMOS_ENDPOINT = Get-CosmosAccountEndpoint -ResourceGroupName $ResourceGroup -Account $serverlessAccount
$COSMOS_ENDPOINT_PROVISIONED = Get-CosmosAccountEndpoint -ResourceGroupName $ResourceGroup -Account $provisionedAccount
if (-not $COSMOS_ENDPOINT) {
  Write-Error "Serverless Cosmos account '$($serverlessAccount.name)' exists, but its endpoint could not be read."
  exit 1
}
if (-not $COSMOS_ENDPOINT_PROVISIONED) {
  Write-Error "Provisioned Cosmos account '$($provisionedAccount.name)' exists, but its endpoint could not be read."
  exit 1
}

# ---- Azure AI Foundry (single AIServices account hosts both chat and embeddings) ----
$foundryJson = az cognitiveservices account list -g $ResourceGroup -o json
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to list Cognitive Services accounts in $ResourceGroup."; exit 1 }
$foundry = @($foundryJson | ConvertFrom-Json) | Where-Object { $_.kind -eq 'AIServices' } | Select-Object -First 1
if (-not $foundry) { Write-Error "No AIServices (Foundry) account found in $ResourceGroup."; exit 1 }
$foundryName = $foundry.name

# Foundry chat completions use the *.services.ai.azure.com host (Entra ID auth).
$FOUNDRY_ENDPOINT = "https://$foundryName.services.ai.azure.com/"
# Embeddings use the *.cognitiveservices.azure.com host with Entra ID auth.
$EMBEDDINGS_ENDPOINT = $foundry.properties.endpoint

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

# ---- Set current-process and persist User-scope environment variables ----
$env:LAB_RESOURCE_GROUP          = $ResourceGroup
$env:COSMOS_ENDPOINT             = $COSMOS_ENDPOINT
$env:COSMOS_ENDPOINT_PROVISIONED = $COSMOS_ENDPOINT_PROVISIONED
$env:FOUNDRY_ENDPOINT            = $FOUNDRY_ENDPOINT
$env:EMBEDDINGS_ENDPOINT         = $EMBEDDINGS_ENDPOINT
$env:EMBEDDINGS_KEY              = $null
$env:COMPLETIONS_MODEL           = $COMPLETIONS_MODEL
$env:EMBEDDINGS_MODEL            = $EMBEDDINGS_MODEL

[System.Environment]::SetEnvironmentVariable('LAB_RESOURCE_GROUP',         $ResourceGroup,               'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT',            $COSMOS_ENDPOINT,             'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT_PROVISIONED',$COSMOS_ENDPOINT_PROVISIONED, 'User')
[System.Environment]::SetEnvironmentVariable('FOUNDRY_ENDPOINT',           $FOUNDRY_ENDPOINT,            'User')
[System.Environment]::SetEnvironmentVariable('EMBEDDINGS_ENDPOINT',        $EMBEDDINGS_ENDPOINT,         'User')
[System.Environment]::SetEnvironmentVariable('EMBEDDINGS_KEY',             $null,                        'User')
[System.Environment]::SetEnvironmentVariable('COMPLETIONS_MODEL',          $COMPLETIONS_MODEL,           'User')
[System.Environment]::SetEnvironmentVariable('EMBEDDINGS_MODEL',           $EMBEDDINGS_MODEL,            'User')

Write-Output ""
Write-Output "Done."
Write-Output "  LAB_RESOURCE_GROUP          = $ResourceGroup"
Write-Output "  COSMOS_ENDPOINT             = $COSMOS_ENDPOINT"
Write-Output "  COSMOS_ENDPOINT_PROVISIONED = $COSMOS_ENDPOINT_PROVISIONED"
Write-Output "  FOUNDRY_ENDPOINT            = $FOUNDRY_ENDPOINT"
Write-Output "  EMBEDDINGS_ENDPOINT         = $EMBEDDINGS_ENDPOINT"
Write-Output "  COMPLETIONS_MODEL           = $COMPLETIONS_MODEL"
Write-Output "  EMBEDDINGS_MODEL            = $EMBEDDINGS_MODEL"
Write-Output "Environment variables are ready in this terminal and future terminals."
