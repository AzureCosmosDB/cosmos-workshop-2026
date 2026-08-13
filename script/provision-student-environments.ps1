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
  [string]$VmSize,

  [Parameter(Mandatory = $false)]
  [ValidateSet('SCSI', 'NVMe')]
  [string]$DiskControllerType,

  [Parameter(Mandatory = $false)]
  [string]$BicepparamFile = (Join-Path $PSScriptRoot '..\bicep\main.bicepparam'),

  [Parameter(Mandatory = $false)]
  [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\out'),

  [Parameter(Mandatory = $false)]
  [switch]$SharedFabric,

  [Parameter(Mandatory = $false)]
  [switch]$NoFabric,

  [Parameter(Mandatory = $false)]
  [bool]$IsDocDB = $false,

  [Parameter(Mandatory = $false)]
  [string]$SharedFabricResourceGroup = 'lab-shared-fabric',

  [Parameter(Mandatory = $false)]
  [string]$SharedFabricCapacityName = 'fabricworkshopshared',

  [Parameter(Mandatory = $false)]
  [ValidateRange(1, 20)]
  [int]$MaxParallelDeployments = 5
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Bastion.psm1') -Force

if ($VmSize -match '_v7$') {
  if ($DiskControllerType -and $DiskControllerType -ne 'NVMe') {
    throw "VM size '$VmSize' requires -DiskControllerType NVMe."
  }
  $DiskControllerType = 'NVMe'
}

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
# Seconds resolution avoids UPN/resource-group collisions between runs started in the same minute.
$batchId = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
# Short, sortable prefix for Entra display names: groups users from the same
# batch together when the directory's display-name column is sorted.
$batchShort = '{0}-{1}' -f $batchId.Substring(4, 4), $batchId.Substring(8, 4)
$csvPath = Join-Path $OutputDirectory "students-$batchId.csv"
$results = New-Object System.Collections.Generic.List[object]
$mirroringRbacFailures = New-Object System.Collections.Generic.List[string]

if ($SharedFabric -and $NoFabric) {
  throw '-SharedFabric and -NoFabric are mutually exclusive.'
}

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
Write-Output "  Database mode: $(if ($IsDocDB) { 'DocumentDB' } else { 'Cosmos DB for NoSQL' })"
Write-Output "  Parallelism:   $MaxParallelDeployments deployment(s)"
if ($NoFabric) {
  Write-Output "  Fabric mode:   none (skipped)"
} elseif ($SharedFabric) {
  Write-Output "  Fabric mode:   shared ($SharedFabricCapacityName in $SharedFabricResourceGroup)"
} else {
  Write-Output "  Fabric mode:   per-student (from bicepparam)"
}
Write-Output ""

for ($batchStart = 1; $batchStart -le $StudentCount; $batchStart += $MaxParallelDeployments) {
  $batchEnd = [Math]::Min($batchStart + $MaxParallelDeployments - 1, $StudentCount)
  $pendingDeployments = New-Object System.Collections.Generic.List[object]

  for ($index = $batchStart; $index -le $batchEnd; $index++) {
  $studentNumber = $index
  $studentLabel = "Lab User $studentNumber"
  $studentDisplayName = "$batchShort Lab User $studentNumber"
  $envName = "l$studentNumber"
  $vmAdminUser = if ($IsDocDB) { "labuser$studentNumber" } else { "lab_user$studentNumber" }
  $vmComputerName = "cosmos-lab$studentNumber"
  $resourceGroupName = "lab-dev$studentNumber-$batchId"
  $deploymentName = "lab-dev$studentNumber-$batchId"
  $studentAlias = "lab_user${studentNumber}_${batchId}"
  $studentUpn = "$studentAlias@$tenantDomain"
  $studentPassword = New-RandomPassword
  $vmAdminPassword = New-RandomPassword
  # Escape embedded quotes so the JSON survives PowerShell -> az.cmd argv marshaling on Windows.
  # Without this, the inner quotes are stripped and az sees {key:value,...} instead of {"key":"value",...}.
  $tagsJson = @{
  env     = $envName
  project = 'cosmos-labs'
  batch   = $batchId
  student = $studentLabel
} | ConvertTo-Json -Compress

$tagsFile = Join-Path $OutputDirectory "tags-$batchId-$index.json"

# Write UTF-8 without BOM, compatible with Windows PowerShell 5.1
[System.IO.File]::WriteAllText(
  $tagsFile,
  $tagsJson,
  [System.Text.UTF8Encoding]::new($false)
)

# bicepparam's fabricAdminMembers is a placeholder; Fabric capacity creation fails
# with "Unable to authorize with Azure Active Directory" if it can't resolve a
# member UPN in this tenant, so override it with the student's own (real) UPN.
$fabricMembersJson = '[' + ($studentUpn | ConvertTo-Json -Compress) + ']'
$fabricMembersFile = Join-Path $OutputDirectory "fabric-admins-$batchId-$index.json"
[System.IO.File]::WriteAllText(
  $fabricMembersFile,
  $fabricMembersJson,
  [System.Text.UTF8Encoding]::new($false)
)

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
    '--parameters', "isDocDB=$($IsDocDB.ToString().ToLowerInvariant())",
    '--parameters', "tags=@$tagsFile",
    '--parameters', "fabricAdminMembers=@$fabricMembersFile"
  )
  if ($SharedFabric -or $NoFabric) {
    $deployParams += @('--parameters', 'deployFabric=false')
  }
  if ($VmSize) {
    $deployParams += @('--parameters', "vmSize=$VmSize")
  }
  if ($DiskControllerType) {
    $deployParams += @('--parameters', "diskControllerType=$DiskControllerType")
  }

  Write-Output "[$studentLabel] running what-if for deployment $deploymentName"
  az deployment sub what-if @deployParams --no-pretty-print --only-show-errors | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "[$studentLabel] what-if failed; deleting newly created Entra user $studentUpn"
    az ad user delete --id $studentUpn --only-show-errors
    throw "What-if failed for deployment '$deploymentName'."
  }

    Write-Output "[$studentLabel] starting deployment $deploymentName"
    az deployment sub create @deployParams --no-wait --only-show-errors | Out-Null
    Assert-LastAzCommand -FailureMessage "Failed to start deployment '$deploymentName'."

    $pendingDeployments.Add([pscustomobject]@{
      StudentLabel = $studentLabel
      StudentUpn = $studentUpn
      StudentPassword = $studentPassword
      StudentObjectId = $studentObjectId
      ResourceGroupName = $resourceGroupName
      DeploymentName = $deploymentName
      DeployParams = $deployParams
      EnvName = $envName
      VmAdminUser = $vmAdminUser
      VmAdminPassword = $vmAdminPassword
      VmComputerName = $vmComputerName
    }) | Out-Null
  }

  Write-Output "Waiting for deployment batch $batchStart-$batchEnd."
  foreach ($pendingDeployment in $pendingDeployments) {
    $studentLabel = $pendingDeployment.StudentLabel
    $studentUpn = $pendingDeployment.StudentUpn
    $studentPassword = $pendingDeployment.StudentPassword
    $studentObjectId = $pendingDeployment.StudentObjectId
    $resourceGroupName = $pendingDeployment.ResourceGroupName
    $deploymentName = $pendingDeployment.DeploymentName
    $envName = $pendingDeployment.EnvName
    $vmAdminUser = $pendingDeployment.VmAdminUser
    $vmAdminPassword = $pendingDeployment.VmAdminPassword
    $vmComputerName = $pendingDeployment.VmComputerName

    Write-Output "[$studentLabel] waiting for deployment $deploymentName"
    az deployment sub wait `
      --name $deploymentName `
      --custom "properties.provisioningState=='Succeeded' || properties.provisioningState=='Failed' || properties.provisioningState=='Canceled'" `
      --timeout 7200 `
      --only-show-errors
    $waitExitCode = $LASTEXITCODE
    $deploymentState = (& az deployment sub show --name $deploymentName --query properties.provisioningState -o tsv 2>$null).Trim()

    # The asynchronous launch is attempt 1. Retry transient ARM failures synchronously
    # against the same deployment and resource group so ARM resumes from current state.
    if ($waitExitCode -ne 0 -or $LASTEXITCODE -ne 0 -or $deploymentState -ne 'Succeeded') {
      $deploymentAttempts = 3
      $deploymentDelaySeconds = 45
      $retryParams = $pendingDeployment.DeployParams
      for ($attempt = 2; $attempt -le $deploymentAttempts; $attempt++) {
        Write-Warning "[$studentLabel] deployment attempt $($attempt - 1) failed; waiting $deploymentDelaySeconds s before retry"
        Start-Sleep -Seconds $deploymentDelaySeconds
        Write-Output "[$studentLabel] retrying deployment $deploymentName (attempt $attempt/$deploymentAttempts)"
        az deployment sub create @retryParams --only-show-errors | Out-Null
        if ($LASTEXITCODE -eq 0) { break }
      }
      Assert-LastAzCommand -FailureMessage "Deployment '$deploymentName' failed after $deploymentAttempts attempts."
    }

  $outputsJson = az deployment sub show --name $deploymentName --query properties.outputs -o json
  Assert-LastAzCommand -FailureMessage "Failed to read outputs for deployment '$deploymentName'."
  $outputs = $outputsJson | ConvertFrom-Json

  Write-Output "[$studentLabel] creating Bastion shareable link"
  $bastionUri = Get-BastionShareableLink `
    -BastionId $outputs.bastionId.value `
    -VmId $outputs.vmId.value

  if (-not $IsDocDB -and -not $NoFabric) {
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
    BastionName = $outputs.bastionName.value
    BastionUri = $bastionUri
    VmAdminUsername = $vmAdminUser
    VmAdminPassword = $vmAdminPassword
    CosmosServerlessAccount = $outputs.cosmosAccountName.value
    CosmosProvisionedAccount = $outputs.cosmosProvisionedAccountName.value
    DocumentDbCluster = $outputs.documentDbClusterName.value
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
  Write-Output "[$studentLabel] Bastion shareable URL: $($row.BastionUri)"

  # Stream this student's row to the roster immediately so a mid-batch failure
  # still leaves a usable record of every student provisioned up to that point.
  if ($results.Count -eq 1) {
    $rowObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
  } else {
    $rowObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Append
  }
  }
}

Write-Output ""
Write-Output "Provisioned $($results.Count) student environment(s)."
Write-Output "Roster written to: $csvPath"
if ($mirroringRbacFailures.Count -gt 0) {
  Write-Warning "Cosmos mirroring RBAC failed for $($mirroringRbacFailures.Count) student(s): $($mirroringRbacFailures -join ', '). Re-apply with script/Set-CosmosMirroringRbac.ps1 before Lab 4B."
}
$results | Format-Table Student, UserPrincipalName, ResourceGroup, VmPublicFqdn, VmAdminUsername -AutoSize
