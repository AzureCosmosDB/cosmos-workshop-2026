# Lab 1B - Account Access
# Grants the signed-in user the data-plane permissions needed for the rest of
# the labs: Cosmos DB Built-in Data Contributor on both Cosmos accounts, and
# Cognitive Services Contributor on the Foundry account.
#
# Prerequisite: run ../SetEnv.ps1 first. It sets LAB_RESOURCE_GROUP, which this
# script uses to discover the account names automatically.

$ErrorActionPreference = 'Stop'

$RESOURCE_GROUP = $env:LAB_RESOURCE_GROUP
if (-not $RESOURCE_GROUP) {
  Write-Error "LAB_RESOURCE_GROUP is not set. Run ../SetEnv.ps1 first (after 'az login')."
  exit 1
}

# ---- Sign in (if not already) ----
az account show -o none 2>$null
if ($LASTEXITCODE -ne 0) {
  az login --allow-no-subscriptions | Out-Null
}

$USER_ID         = (az ad signed-in-user show --query id -o tsv).Trim()
$SUBSCRIPTION_ID = (az account show --query id -o tsv).Trim()
Write-Output "Signed in as object ID: $USER_ID"
Write-Output "Subscription:           $SUBSCRIPTION_ID"
Write-Output "Resource group:         $RESOURCE_GROUP"

# ---- Discover account names from the resource group ----
$cosmosAccounts = @(az cosmosdb list -g $RESOURCE_GROUP -o json | ConvertFrom-Json)
$serverless = $cosmosAccounts | Where-Object {
  ($_.capabilities | Where-Object { $_.name -eq 'EnableServerless' })
} | Select-Object -First 1
$provisioned = $cosmosAccounts | Where-Object {
  -not ($_.capabilities | Where-Object { $_.name -eq 'EnableServerless' })
} | Select-Object -First 1

if (-not $serverless)  { Write-Error "No serverless Cosmos account found in $RESOURCE_GROUP."; exit 1 }
if (-not $provisioned) { Write-Error "No provisioned Cosmos account found in $RESOURCE_GROUP."; exit 1 }

$ACCT_NAME             = $serverless.name
$ACCT_NAME_PROVISIONED = $provisioned.name

$FOUNDRY_ACCT_NAME = (az cognitiveservices account list -g $RESOURCE_GROUP --query "[?kind=='AIServices'] | [0].name" -o tsv).Trim()
if (-not $FOUNDRY_ACCT_NAME) { Write-Error "No AIServices (Foundry) account found in $RESOURCE_GROUP."; exit 1 }

Write-Output "Discovered accounts:"
Write-Output "  Cosmos (serverless):  $ACCT_NAME"
Write-Output "  Cosmos (provisioned): $ACCT_NAME_PROVISIONED"
Write-Output "  Foundry:              $FOUNDRY_ACCT_NAME"

# ---- Cosmos data-plane access (built-in Data Contributor role) ----
# The role definition ID 00000000-0000-0000-0000-000000000002 is the Cosmos DB
# Built-in Data Contributor role. This is *data-plane* RBAC (separate from
# Azure control-plane RBAC), required for the SDK to call read/write APIs.
az cosmosdb sql role assignment create `
  --resource-group $RESOURCE_GROUP `
  --account-name $ACCT_NAME `
  --role-definition-id 00000000-0000-0000-0000-000000000002 `
  --principal-id $USER_ID `
  --scope "/"
Write-Output "Cosmos DB Data Contributor role granted on $ACCT_NAME"

az cosmosdb sql role assignment create `
  --resource-group $RESOURCE_GROUP `
  --account-name $ACCT_NAME_PROVISIONED `
  --role-definition-id 00000000-0000-0000-0000-000000000002 `
  --principal-id $USER_ID `
  --scope "/"
Write-Output "Cosmos DB Data Contributor role granted on $ACCT_NAME_PROVISIONED"

# ---- Foundry data-plane access (Cognitive Services Contributor) for Entra-auth chat completions ----
$FOUNDRY_SCOPE = "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_ACCT_NAME"
az role assignment create --assignee $USER_ID --role "Cognitive Services Contributor" --scope $FOUNDRY_SCOPE
Write-Output "Cognitive Services Contributor role granted on $FOUNDRY_ACCT_NAME"

# ---- Mirror the cosmos endpoints into env vars for SDK samples ----
# SetEnv.ps1 already wrote these, but re-set them here so that re-running this
# script after recreating an account picks up the new endpoints.
$endpoint            = "https://$ACCT_NAME.documents.azure.com:443/"
$endpointProvisioned = "https://$ACCT_NAME_PROVISIONED.documents.azure.com:443/"
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT',                 $endpoint,             'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ACCOUNT_NAME',             $ACCT_NAME,            'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ACCOUNT_NAME_PROVISIONED', $ACCT_NAME_PROVISIONED,'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT_PROVISIONED',     $endpointProvisioned,  'User')

Write-Output ""
Write-Output "Done. Restart VS Code / your terminal so the SDK picks up the env vars."
