param(
  [Parameter(Mandatory = $true)]
  [ValidateRange(1, 999)]
  [int]$StudentCount,

  [Parameter(Mandatory = $false)]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $false)]
  [string]$TenantDomain,

  [Parameter(Mandatory = $false)]
  [string]$Location = 'westus',

  [Parameter(Mandatory = $false)]
  [string]$BicepparamFile = (Join-Path $PSScriptRoot '..\bicep\main.bicepparam'),

  [Parameter(Mandatory = $false)]
  [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\out'),

  [Parameter(Mandatory = $false)]
  [switch]$SharedFabric,

  [Parameter(Mandatory = $false)]
  [string]$SharedFabricResourceGroup = 'lab-shared-fabric',

  [Parameter(Mandatory = $false)]
  [string]$SharedFabricCapacityName = 'fabricworkshopshared'
)

$ErrorActionPreference = 'Stop'

function Assert-LastAzCommand {
  param([Parameter(Mandatory = $true)][string]$FailureMessage)
  if ($LASTEXITCODE -ne 0) {
    throw $FailureMessage
  }
}

function New-RandomPassword {
  param([Parameter(Mandatory = $false)][ValidateRange(12, 128)][int]$Length = 20)

  # Build a password guaranteed to satisfy Windows complexity (upper, lower, digit, symbol).
  $upper = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZ'
  $lower = [char[]]'abcdefghijkmnopqrstuvwxyz'
  $digit = [char[]]'23456789'
  # Avoid cmd.exe metacharacters (% ^ &) and delayed-expansion trigger (!) — passwords
  # pass through az.cmd to az ad user create, where cmd's percent-expansion would
  # mangle the value before Entra ever sees it. Remaining symbols are all in
  # Entra's allowed-symbols list and are inert in cmd argv.
  $symbol = [char[]]'@#$*-_=+'
  $all = $upper + $lower + $digit + $symbol

  $chars = @(
    $upper  | Get-Random
    $lower  | Get-Random
    $digit  | Get-Random
    $symbol | Get-Random
  )
  for ($i = $chars.Count; $i -lt $Length; $i++) {
    $chars += ($all | Get-Random)
  }
  -join ($chars | Sort-Object { Get-Random })
}

function Get-TenantDomain {
  param([string]$ExplicitDomain)

  if ($ExplicitDomain) { return $ExplicitDomain.Trim() }

  # Authoritative: Microsoft Graph default-domain lookup. Works across az CLI versions.
  $domain = & az rest --method get --url 'https://graph.microsoft.com/v1.0/domains' --query "value[?isDefault].id | [0]" -o tsv 2>$null
  if ($LASTEXITCODE -eq 0 -and $domain) { return $domain.Trim() }

  # Newer az CLI (2.71+) exposes tenantDefaultDomain directly.
  $domain = & az account show --query tenantDefaultDomain -o tsv 2>$null
  if ($LASTEXITCODE -eq 0 -and $domain) { return $domain.Trim() }

  # Fallback: trainer's UPN suffix. Correct unless the tenant default domain
  # differs from the signed-in user's UPN domain (rare for workshop accounts).
  $userName = & az account show --query 'user.name' -o tsv 2>$null
  if ($LASTEXITCODE -eq 0 -and $userName -and $userName -like '*@*') {
    return ($userName -split '@', 2)[1].Trim()
  }

  throw 'Unable to determine the tenant default domain. Pass -TenantDomain explicitly.'
}

if (-not (Test-Path $BicepparamFile)) {
  throw "Bicep parameter file not found: $BicepparamFile"
}

if (-not (Test-Path $OutputDirectory)) {
  New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

if ($SubscriptionId) {
  az account set --subscription $SubscriptionId --only-show-errors
  Assert-LastAzCommand -FailureMessage "Failed to select subscription '$SubscriptionId'."
}

$activeSubscriptionId = (& az account show --query id -o tsv).Trim()
Assert-LastAzCommand -FailureMessage 'Failed to read the active az subscription id. Run az login first.'

$tenantDomain = Get-TenantDomain -ExplicitDomain $TenantDomain
$batchId = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmm')
# Short, sortable prefix for Entra display names: groups users from the same
# batch together when the directory's display-name column is sorted.
$batchShort = '{0}-{1}' -f $batchId.Substring(4, 4), $batchId.Substring(8, 4)
$csvPath = Join-Path $OutputDirectory "students-$batchId.csv"
$results = New-Object System.Collections.Generic.List[object]
$mirroringRbacFailures = New-Object System.Collections.Generic.List[string]

$sharedFabricCapacityId = $null
if ($SharedFabric) {
  $sharedFabricCapacityId = (& az resource show `
    --resource-group $SharedFabricResourceGroup `
    --name $SharedFabricCapacityName `
    --resource-type 'Microsoft.Fabric/capacities' `
    --query id -o tsv 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or -not $sharedFabricCapacityId) {
    throw "Shared Fabric capacity '$SharedFabricCapacityName' not found in resource group '$SharedFabricResourceGroup'. Run provision-shared-fabric.ps1 first."
  }
}

Write-Output "Provisioning $StudentCount student environment(s)."
Write-Output "  Batch ID:      $batchId"
Write-Output "  Tenant domain: $tenantDomain"
Write-Output "  Location:      $Location"
if ($SharedFabric) {
  Write-Output "  Fabric mode:   shared ($SharedFabricCapacityName in $SharedFabricResourceGroup)"
} else {
  Write-Output "  Fabric mode:   per-student (from bicepparam)"
}
Write-Output ""

for ($index = 1; $index -le $StudentCount; $index++) {
  $studentNumber = $index
  $studentLabel = "Lab User $studentNumber"
  $studentDisplayName = "$batchShort Lab User $studentNumber"
  $envName = "l$studentNumber"
  $vmAdminUser = "lab_user$studentNumber"
  $vmComputerName = "cosmos-lab$studentNumber"
  $resourceGroupName = "lab-dev$studentNumber-$batchId"
  $deploymentName = "lab-dev$studentNumber-$batchId"
  $studentAlias = "lab_user${studentNumber}_${batchId}"
  $studentUpn = "$studentAlias@$tenantDomain"
  $studentPassword = New-RandomPassword
  $vmAdminPassword = New-RandomPassword
  # Escape embedded quotes so the JSON survives PowerShell -> az.cmd argv marshaling on Windows.
  # Without this, the inner quotes are stripped and az sees {key:value,...} instead of {"key":"value",...}.
  $tagsJson = ((@{
    env = $envName
    project = 'cosmos-labs'
    batch = $batchId
    student = $studentLabel
  } | ConvertTo-Json -Compress) -replace '"', '\"')

  Write-Output "[$studentLabel] creating Entra user $studentUpn"
  az ad user create `
    --display-name $studentDisplayName `
    --user-principal-name $studentUpn `
    --password $studentPassword `
    --force-change-password-next-sign-in true `
    --mail-nickname $studentAlias `
    --only-show-errors | Out-Null
  Assert-LastAzCommand -FailureMessage "Failed to create Entra user '$studentUpn'."

  $studentObjectId = (& az ad user show --id $studentUpn --query id -o tsv 2>$null).Trim()
  Assert-LastAzCommand -FailureMessage "Failed to read object ID for user '$studentUpn'."
  if (-not $studentObjectId) {
    throw "Created student user but could not resolve the object ID for $studentUpn."
  }

  $deployParams = @(
    '--location', $Location,
    '--name', $deploymentName,
    '--parameters', $BicepparamFile,
    '--parameters', "envName=$envName",
    '--parameters', "location=$Location",
    '--parameters', "resourceGroupName=$resourceGroupName",
    '--parameters', "vmAdminUsername=$vmAdminUser",
    '--parameters', "vmAdminPassword=$vmAdminPassword",
    '--parameters', "vmComputerName=$vmComputerName",
    '--parameters', "studentOwnerObjectId=$studentObjectId",
    '--parameters', "tags=$tagsJson"
  )
  if ($SharedFabric) {
    $deployParams += @('--parameters', 'deployFabric=false')
  }

  Write-Output "[$studentLabel] running what-if for deployment $deploymentName"
  az deployment sub what-if @deployParams --no-pretty-print --only-show-errors | Out-Null
  Assert-LastAzCommand -FailureMessage "What-if failed for deployment '$deploymentName'."

  # Retry transient ARM failures (e.g., Cognitive Services 'provisioning state is not
  # terminal' races between the AI Foundry account and its child project / model
  # deployments). ARM deployments are idempotent, so re-running with the same params
  # against the same RG just resumes from current state.
  $deploymentAttempts = 3
  $deploymentDelaySeconds = 45
  for ($attempt = 1; $attempt -le $deploymentAttempts; $attempt++) {
    Write-Output "[$studentLabel] deploying $deploymentName (attempt $attempt/$deploymentAttempts)"
    az deployment sub create @deployParams --only-show-errors | Out-Null
    if ($LASTEXITCODE -eq 0) { break }
    if ($attempt -lt $deploymentAttempts) {
      Write-Warning "[$studentLabel] deployment attempt $attempt failed; waiting $deploymentDelaySeconds s before retry (often a transient AI Foundry / Cognitive Services race)"
      Start-Sleep -Seconds $deploymentDelaySeconds
    }
  }
  Assert-LastAzCommand -FailureMessage "Deployment '$deploymentName' failed after $deploymentAttempts attempts."

  $outputsJson = az deployment sub show --name $deploymentName --query properties.outputs -o json
  Assert-LastAzCommand -FailureMessage "Failed to read outputs for deployment '$deploymentName'."
  $outputs = $outputsJson | ConvertFrom-Json

  $cosmosServerlessName = $outputs.cosmosAccountName.value
  Write-Output "[$studentLabel] granting Cosmos mirroring RBAC on $cosmosServerlessName"
  try {
    & (Join-Path $PSScriptRoot 'Set-CosmosMirroringRbac.ps1') `
      -SubscriptionId $activeSubscriptionId `
      -ResourceGroup $resourceGroupName `
      -AccountName $cosmosServerlessName `
      -PrincipalId $studentObjectId
  } catch {
    Write-Warning "[$studentLabel] Cosmos mirroring RBAC failed: $($_.Exception.Message)"
    Write-Warning "  Re-run: ./script/Set-CosmosMirroringRbac.ps1 -SubscriptionId $activeSubscriptionId -ResourceGroup $resourceGroupName -AccountName $cosmosServerlessName -PrincipalId $studentObjectId"
    $mirroringRbacFailures.Add($studentLabel) | Out-Null
  }

  $row = [ordered]@{
    Student = $studentLabel
    UserPrincipalName = $studentUpn
    TempPassword = $studentPassword
    ObjectId = $studentObjectId
    ResourceGroup = $resourceGroupName
    VmName = $outputs.vmName.value
    VmComputerName = $vmComputerName
    VmPublicIp = $outputs.vmPublicIpAddress.value
    VmPublicFqdn = $outputs.vmPublicIp.value
    VmAdminUsername = $vmAdminUser
    VmAdminPassword = $vmAdminPassword
    CosmosServerlessAccount = $outputs.cosmosAccountName.value
    CosmosProvisionedAccount = $outputs.cosmosProvisionedAccountName.value
    FoundryAccount = $outputs.foundryAccountName.value
    StorageAccount = $outputs.storageAccountName.value
    EnvName = $envName
    BatchId = $batchId
  }
  if ($SharedFabric) {
    $row.FabricSharedCapacityId = $sharedFabricCapacityId
    $row.FabricSharedCapacityName = $SharedFabricCapacityName
    $row.FabricWorkspaceId = ''
    $row.FabricWorkspaceName = ''
  }
  $rowObject = [pscustomobject]$row
  $results.Add($rowObject)

  # Stream this student's row to the roster immediately so a mid-batch failure
  # still leaves a usable record of every student provisioned up to that point.
  if ($results.Count -eq 1) {
    $rowObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
  } else {
    $rowObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Append
  }
}

Write-Output ""
Write-Output "Provisioned $($results.Count) student environment(s)."
Write-Output "Roster written to: $csvPath"
if ($mirroringRbacFailures.Count -gt 0) {
  Write-Warning "Cosmos mirroring RBAC failed for $($mirroringRbacFailures.Count) student(s): $($mirroringRbacFailures -join ', '). Re-apply with script/Set-CosmosMirroringRbac.ps1 before Lab 4B."
}
$results | Format-Table Student, UserPrincipalName, ResourceGroup, VmPublicFqdn, VmAdminUsername -AutoSize
