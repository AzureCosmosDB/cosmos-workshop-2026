param(
  [Parameter(Mandatory = $true)]
  [string]$ResourceGroupName,

  # Defaults to the currently signed-in az identity (user or service principal) when omitted.
  [Parameter(Mandatory = $false)]
  [string]$UserPrincipalName,

  [Parameter(Mandatory = $false)]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $false)]
  [string]$Location = 'westus',

  [Parameter(Mandatory = $false)]
  [string]$VmSize = 'Standard_D4ds_v7',

  [Parameter(Mandatory = $false)]
  [ValidateSet('SCSI', 'NVMe')]
  [string]$DiskControllerType = 'NVMe',

  [Parameter(Mandatory = $false)]
  [string]$EnvName,

  [Parameter(Mandatory = $false)]
  [string]$VmAdminUsername,

  [Parameter(Mandatory = $false)]
  [string]$VmComputerName = 'cosmos-lab',

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
  [string]$SharedFabricCapacityName = 'fabricworkshopshared'
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
  # pass through az.cmd to az deployment create, where cmd's percent-expansion would
  # mangle the value before it reaches the VM extension. Remaining symbols are all in
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

function Assert-ValidVmAdminUsername {
  param([Parameter(Mandatory = $true)][string]$Username)

  $reservedUsernames = @(
    'administrator', 'admin', 'user', 'user1', 'test', 'user2', 'test1', 'user3',
    'admin1', '1', '123', 'a', 'actuser', 'adm', 'admin2', 'aspnet', 'backup',
    'console', 'david', 'guest', 'john', 'owner', 'root', 'server', 'sql', 'support',
    'support_388945a0', 'sys', 'test2', 'test3', 'user4', 'user5'
  )

  if ($Username.Length -gt 20) {
    throw "VM admin username '$Username' exceeds the Windows VM limit of 20 characters."
  }
  if ($Username.EndsWith('.') -or $Username -match '[\x00-\x1f\\/"\[\]:|<>+=;,?*@&]') {
    throw "VM admin username '$Username' contains characters that Azure Windows VMs do not allow."
  }
  if ($reservedUsernames -contains $Username.ToLowerInvariant()) {
    throw "VM admin username '$Username' is reserved by Azure. Choose a different -VmAdminUsername value."
  }
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

if ($SharedFabric -and $NoFabric) {
  throw '-SharedFabric and -NoFabric are mutually exclusive.'
}

$usingSignedInIdentity = -not $UserPrincipalName
if ($usingSignedInIdentity) {
  $UserPrincipalName = (& az account show --query 'user.name' -o tsv).Trim()
  Assert-LastAzCommand -FailureMessage 'Failed to read the signed-in az identity. Run az login first, or pass -UserPrincipalName explicitly.'
}

# Fail fast rather than silently creating a user: this script is for students who already
# have an Azure AD identity and must not provision new Entra identities.
# Service principals resolve via az ad sp (UserPrincipalName is then the app/client ID); everyone else via az ad user.
$signedInType = (& az account show --query 'user.type' -o tsv 2>$null)
if ($usingSignedInIdentity -and $signedInType -and $signedInType.Trim() -eq 'servicePrincipal') {
  $studentObjectId = (& az ad sp show --id $UserPrincipalName --query id -o tsv 2>$null)
  Assert-LastAzCommand -FailureMessage "Service principal '$UserPrincipalName' was not found in the current tenant."
} else {
  $studentObjectId = (& az ad user show --id $UserPrincipalName --query id -o tsv 2>$null)
  Assert-LastAzCommand -FailureMessage "User '$UserPrincipalName' was not found in the current tenant. Verify the UPN and that you're signed into the right tenant."
}
if (-not $studentObjectId) {
  throw "Could not resolve object ID for '$UserPrincipalName'."
}
$studentObjectId = $studentObjectId.Trim()

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
# main.bicep's envName param has @maxLength(4); resource-name uniqueness comes from
# uniqueString(resourceGroup().id) downstream, so envName just needs to be short and stable.
if (-not $EnvName) {
  $rgAlnum = ($ResourceGroupName -replace '[^a-zA-Z0-9]', '').ToLower()
  $EnvName = if ($rgAlnum.Length -ge 4) { $rgAlnum.Substring(0, 4) } elseif ($rgAlnum) { $rgAlnum } else { 'std' }
}
if ($EnvName.Length -gt 4) {
  throw "-EnvName '$EnvName' exceeds the 4-character limit enforced by main.bicep's envName parameter."
}
if (-not $VmAdminUsername) {
  $alias = ($UserPrincipalName -split '@', 2)[0] -replace '[^a-zA-Z0-9]', ''
  if ($alias.Length -gt 16) { $alias = $alias.Substring(0, 16) }
  if (-not $alias) { $alias = 'user' }
  $VmAdminUsername = "lab_$alias"
}
Assert-ValidVmAdminUsername -Username $VmAdminUsername

$vmName = "lab-vm-$EnvName-01"
$resourceGroupExists = [System.Convert]::ToBoolean((& az group exists --name $ResourceGroupName -o tsv).Trim())
if ($resourceGroupExists) {
  $existingDiskControllerType = [string](& az vm list --resource-group $ResourceGroupName --query "[?name=='$vmName'] | [0].storageProfile.diskControllerType" -o tsv)
  if ($existingDiskControllerType -and $existingDiskControllerType.Trim() -ne $DiskControllerType) {
    throw "Existing VM '$vmName' uses $($existingDiskControllerType.Trim()), which cannot be converted in place to $DiskControllerType. Use a new resource group to deploy $VmSize."
  }
}

$deploymentName = "$ResourceGroupName-$timestamp"
$vmAdminPassword = New-RandomPassword
$csvPath = Join-Path $OutputDirectory "student-$ResourceGroupName-$timestamp.csv"
$vnetName = "$EnvName-vnet"
$subnetName = "$EnvName-subnet"
$existingSubnetId = [string](& az network vnet list --resource-group $ResourceGroupName --query "[?name=='$vnetName'].subnets[?name=='$subnetName'].id | [0][0]" -o tsv)
$useExistingVnet = $LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($existingSubnetId)

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

Write-Output "Provisioning environment for existing user."
Write-Output "  User:            $UserPrincipalName"
Write-Output "  Resource group:  $ResourceGroupName"
Write-Output "  Location:        $Location"
Write-Output "  Database mode:   $(if ($IsDocDB) { 'DocumentDB' } else { 'Cosmos DB for NoSQL' })"
Write-Output "  Network mode:    $(if ($useExistingVnet) { "reuse existing ($vnetName)" } else { 'create new' })"
if ($NoFabric) {
  Write-Output "  Fabric mode:     none (skipped)"
} elseif ($SharedFabric) {
  Write-Output "  Fabric mode:     shared ($SharedFabricCapacityName in $SharedFabricResourceGroup)"
} else {
  Write-Output "  Fabric mode:     per-student (from bicepparam)"
}
Write-Output ""

# Escape embedded quotes so the JSON survives PowerShell -> az.cmd argv marshaling on Windows.
# Without this, the inner quotes are stripped and az sees {key:value,...} instead of {"key":"value",...}.
$tagsJson = @{
  env     = $EnvName
  project = 'cosmos-labs'
  student = $UserPrincipalName
} | ConvertTo-Json -Compress

$tagsFile = Join-Path $OutputDirectory "tags-$ResourceGroupName-$timestamp.json"
[System.IO.File]::WriteAllText(
  $tagsFile,
  $tagsJson,
  [System.Text.UTF8Encoding]::new($false)
)

# bicepparam's fabricAdminMembers is a placeholder; Fabric capacity creation fails
# with "Unable to authorize with Azure Active Directory" if it can't resolve a
# member UPN in this tenant, so override it with the student's own (real) UPN.
$fabricMembersJson = '[' + ($UserPrincipalName | ConvertTo-Json -Compress) + ']'
$fabricMembersFile = Join-Path $OutputDirectory "fabric-admins-$ResourceGroupName-$timestamp.json"
[System.IO.File]::WriteAllText(
  $fabricMembersFile,
  $fabricMembersJson,
  [System.Text.UTF8Encoding]::new($false)
)

$deployParams = @(
  '--location', $Location,
  '--name', $deploymentName,
  '--parameters', $BicepparamFile,
  '--parameters', "envName=$EnvName",
  '--parameters', "location=$Location",
  '--parameters', "resourceGroupName=$ResourceGroupName",
  '--parameters', "vmAdminUsername=$VmAdminUsername",
  '--parameters', "vmAdminPassword=$vmAdminPassword",
  '--parameters', "vmComputerName=$VmComputerName",
  '--parameters', "studentOwnerObjectId=$studentObjectId",
  '--parameters', "isDocDB=$($IsDocDB.ToString().ToLowerInvariant())",
  '--parameters', "useExistingVnet=$($useExistingVnet.ToString().ToLowerInvariant())",
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

Write-Output "running what-if for deployment $deploymentName"
az deployment sub what-if @deployParams --no-pretty-print --only-show-errors | Out-Null
Assert-LastAzCommand -FailureMessage "What-if failed for deployment '$deploymentName'."

# Retry transient ARM failures (e.g., Cognitive Services 'provisioning state is not
# terminal' races between the AI Foundry account and its child project / model
# deployments). ARM deployments are idempotent, so re-running with the same params
# against the same RG just resumes from current state.
$deploymentAttempts = 3
$deploymentDelaySeconds = 45
for ($attempt = 1; $attempt -le $deploymentAttempts; $attempt++) {
  Write-Output "deploying $deploymentName (attempt $attempt/$deploymentAttempts)"
  az deployment sub create @deployParams --only-show-errors | Out-Null
  if ($LASTEXITCODE -eq 0) { break }
  if ($attempt -lt $deploymentAttempts) {
    Write-Warning "deployment attempt $attempt failed; waiting $deploymentDelaySeconds s before retry (often a transient AI Foundry / Cognitive Services race)"
    Start-Sleep -Seconds $deploymentDelaySeconds
  }
}
Assert-LastAzCommand -FailureMessage "Deployment '$deploymentName' failed after $deploymentAttempts attempts."

$outputsJson = az deployment sub show --name $deploymentName --query properties.outputs -o json
Assert-LastAzCommand -FailureMessage "Failed to read outputs for deployment '$deploymentName'."
$outputs = $outputsJson | ConvertFrom-Json

Write-Output 'creating Bastion shareable link'
$bastionUri = Get-BastionShareableLink `
  -BastionId $outputs.bastionId.value `
  -VmId $outputs.vmId.value

$mirroringRbacFailed = $false
if (-not $IsDocDB -and -not $NoFabric) {
  $cosmosServerlessName = $outputs.cosmosAccountName.value
  Write-Output "granting Cosmos mirroring RBAC on $cosmosServerlessName"
  try {
    & (Join-Path $PSScriptRoot 'Set-CosmosMirroringRbac.ps1') `
      -SubscriptionId $activeSubscriptionId `
      -ResourceGroup $ResourceGroupName `
      -AccountName $cosmosServerlessName `
      -PrincipalId $studentObjectId
  } catch {
    Write-Warning "Cosmos mirroring RBAC failed: $($_.Exception.Message)"
    Write-Warning "  Re-run: ./script/Set-CosmosMirroringRbac.ps1 -SubscriptionId $activeSubscriptionId -ResourceGroup $ResourceGroupName -AccountName $cosmosServerlessName -PrincipalId $studentObjectId"
    $mirroringRbacFailed = $true
  }
}

$row = [ordered]@{
  UserPrincipalName        = $UserPrincipalName
  ObjectId                 = $studentObjectId
  ResourceGroup            = $ResourceGroupName
  VmName                   = $outputs.vmName.value
  VmComputerName            = $VmComputerName
  VmPublicIp               = $outputs.vmPublicIpAddress.value
  VmPublicFqdn             = $outputs.vmPublicIp.value
  BastionName              = $outputs.bastionName.value
  BastionUri               = $bastionUri
  VmAdminUsername          = $VmAdminUsername
  VmAdminPassword          = $vmAdminPassword
  CosmosServerlessAccount  = $outputs.cosmosAccountName.value
  CosmosProvisionedAccount = $outputs.cosmosProvisionedAccountName.value
  DocumentDbCluster        = $outputs.documentDbClusterName.value
  FoundryAccount           = $outputs.foundryAccountName.value
  StorageAccount           = $outputs.storageAccountName.value
  EnvName                  = $EnvName
}
if ($SharedFabric) {
  $row.FabricSharedCapacityId = $sharedFabricCapacityId
  $row.FabricSharedCapacityName = $SharedFabricCapacityName
}
$rowObject = [pscustomobject]$row
$rowObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Output ""
Write-Output "Provisioned environment for $UserPrincipalName."
Write-Output "Roster written to: $csvPath"
Write-Output "Bastion shareable URL: $($row.BastionUri)"
if ($mirroringRbacFailed) {
  Write-Warning "Cosmos mirroring RBAC failed for $UserPrincipalName. Re-apply with script/Set-CosmosMirroringRbac.ps1 before Lab 4B."
}
$rowObject | Format-Table UserPrincipalName, ResourceGroup, VmPublicFqdn, VmAdminUsername -AutoSize
