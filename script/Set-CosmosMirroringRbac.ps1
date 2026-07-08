# Grant the Cosmos DB data-plane RBAC required for Microsoft Fabric mirroring.
# Creates a custom role definition (readMetadata + readAnalytics) on the target
# Cosmos account if missing, then assigns it to the specified principal.
#
# Transliteration of the Microsoft-published bash sample at:
# https://github.com/Azure-Samples/azure-cli-samples/blob/master/cosmosdb/common/rbac-cosmos-mirror.sh
# Core az CLI commands, JMESPath idempotency queries, JSON body shape, role
# name, and data actions are unchanged. Stripped: interactive prompts (params
# instead), JSON-file export option, signed-in-user resolution (PrincipalId
# param instead).
#
# Auth: piggybacks on the caller's `az login` context — no Az PowerShell
# modules required.

param(
    [Parameter(Mandatory = $true)][string]$SubscriptionId,
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [Parameter(Mandatory = $true)][string]$AccountName,
    [Parameter(Mandatory = $true)][string]$PrincipalId,
    [Parameter(Mandatory = $false)][string]$RoleName = 'Custom-CosmosDB-Metadata-Analytics-Reader'
)

$ErrorActionPreference = 'Stop'

& az account set --subscription $SubscriptionId --only-show-errors
if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription '$SubscriptionId'." }

$scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.DocumentDB/databaseAccounts/$AccountName"

# ---- Ensure role definition exists (idempotent by role name) ----
$roleId = (& az cosmosdb sql role definition list `
    --account-name $AccountName `
    --resource-group $ResourceGroup `
    --query "[?roleName=='$RoleName'].id | [0]" -o tsv 2>$null)
if ($roleId) { $roleId = $roleId.Trim() }

if (-not $roleId -or $roleId -eq 'None' -or $roleId -eq 'null') {
    $roleId = [Guid]::NewGuid().ToString()

    # Escape embedded quotes so the JSON survives PowerShell -> az.cmd argv marshaling on Windows.
    # Without this, the inner quotes are stripped and az sees {Id:...,RoleName:...} instead of valid JSON.
    $body = (@{
        Id = $roleId
        RoleName = $RoleName
        Type = 'CustomRole'
        AssignableScopes = @($scope)
        Permissions = @(
            @{
                DataActions = @(
                    'Microsoft.DocumentDB/databaseAccounts/readMetadata',
                    'Microsoft.DocumentDB/databaseAccounts/readAnalytics'
                )
                NotDataActions = @()
            }
        )
    } | ConvertTo-Json -Depth 5 -Compress) -replace '"', '\"'

    & az cosmosdb sql role definition create `
        --account-name $AccountName `
        --resource-group $ResourceGroup `
        --body $body --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Role definition create failed on '$AccountName'."
    }
}

# ---- Ensure role assignment exists (idempotent by principal + role + scope) ----
$existingAssignmentId = (& az cosmosdb sql role assignment list `
    --account-name $AccountName `
    --resource-group $ResourceGroup `
    --scope $scope `
    --query "[?principalId=='$PrincipalId' && roleDefinitionId=='$roleId'] | [0].id" -o tsv 2>$null)
if ($existingAssignmentId) { $existingAssignmentId = $existingAssignmentId.Trim() }

if (-not $existingAssignmentId -or $existingAssignmentId -eq 'None' -or $existingAssignmentId -eq 'null') {
    & az cosmosdb sql role assignment create `
        --account-name $AccountName `
        --resource-group $ResourceGroup `
        --role-definition-id $roleId `
        --principal-id $PrincipalId `
        --scope $scope --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Role assignment create failed on '$AccountName' for principal '$PrincipalId'."
    }
}
