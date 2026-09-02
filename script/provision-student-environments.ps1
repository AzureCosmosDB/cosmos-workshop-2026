[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory = $true)]
  [ValidateRange(1, 999)]
  [int]$StudentCount,

  [Parameter(Mandatory = $false)]
  [ValidateRange(1, 999)]
  [int]$StartStudentNumber = 1,

  [Parameter(Mandatory = $false)]
  [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9-]{0,49}$')]
  [string]$LabId,

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
  [switch]$PerStudentFabric,

  [Parameter(Mandatory = $false)]
  [bool]$IsDocDB = $false,

  [Parameter(Mandatory = $false)]
  [string]$SharedFabricResourceGroup = 'lab-shared-fabric',

  [Parameter(Mandatory = $false)]
  [string]$SharedFabricCapacityName = 'fabricworkshopshared',

  [Parameter(Mandatory = $false)]
  [ValidateRange(1, 20)]
  [int]$MaxParallelDeployments = 5,

  [Parameter(Mandatory = $false)]
  [switch]$SkipDeallocate
)

$ErrorActionPreference = 'Stop'
# On PS 7.3+, az.cmd stderr/non-zero exit is promoted to a terminating error under
# $ErrorActionPreference='Stop', even with 2>$null. This has no effect on Windows
# PowerShell 5.1, which hits the same problem via classic native-stderr handling;
# Invoke-AzQuiet (below) is the actual, version-independent fix for expected az failures.
$PSNativeCommandUseErrorActionPreference = $false

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

function Invoke-AzWithRetry {
  # Entra ID intermittently returns "Insufficient privileges to complete the operation"
  # for a moment after rapid successive object creation (replication lag / throttling,
  # not an actual permissions problem); retry a few times with backoff before giving up.
  param(
    [Parameter(Mandatory = $true)][ScriptBlock]$ScriptBlock,
    [Parameter(Mandatory = $true)][string]$FailureMessage,
    [int]$MaxAttempts = 4,
    [int]$InitialDelaySeconds = 5
  )
  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    & $ScriptBlock
    if ($LASTEXITCODE -eq 0) { return }
    if ($attempt -eq $MaxAttempts) { throw $FailureMessage }
    $delaySeconds = $InitialDelaySeconds * [Math]::Pow(2, $attempt - 1)
    Write-Warning "$FailureMessage Retrying in $delaySeconds second(s) (attempt $attempt/$MaxAttempts)."
    Start-Sleep -Seconds $delaySeconds
  }
}

function Invoke-AzQuiet {
  # Runs an az command expected to sometimes fail (existence checks) without letting
  # $ErrorActionPreference='Stop' promote its stderr output into a terminating error.
  # A failed native command with no stdout returns PowerShell's "no pipeline output"
  # value, which behaves like $null but throws if cast with [string]; interpolation
  # ("$result") coerces it to a real empty string so callers can safely call .Trim().
  param([Parameter(Mandatory = $true)][ScriptBlock]$ScriptBlock)
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $result = & $ScriptBlock 2>$null
  } finally {
    $ErrorActionPreference = $prevEap
  }
  return "$result"
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

function Set-CsvRowWithRetry {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][psobject]$InputObject,
    [Parameter(Mandatory = $true)][string]$KeyProperty,
    [Parameter(Mandatory = $false)][ValidateRange(1, 120)][int]$MaxAttempts = 30,
    [Parameter(Mandatory = $false)][ValidateRange(1, 60)][int]$RetryDelaySeconds = 2
  )

  $encoding = [System.Text.UTF8Encoding]::new($false)

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    try {
      $stream = [System.IO.FileStream]::new(
        $Path,
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::Read
      )
      try {
        $reader = [System.IO.StreamReader]::new($stream, $encoding, $true, 1024, $true)
        try {
          $existingCsv = $reader.ReadToEnd()
        } finally {
          $reader.Dispose()
        }

        $rows = if ([string]::IsNullOrWhiteSpace($existingCsv)) {
          @()
        } else {
          @($existingCsv | ConvertFrom-Csv)
        }
        $keyValue = [string]$InputObject.$KeyProperty
        $updatedRows = @($rows | Where-Object { [string]$_.$KeyProperty -ne $keyValue }) + @($InputObject)
        $columns = @($InputObject.PSObject.Properties.Name)
        $csvLines = @($updatedRows | Select-Object -Property $columns | ConvertTo-Csv -NoTypeInformation)

        $stream.Position = 0
        $stream.SetLength(0)
        $writer = [System.IO.StreamWriter]::new($stream, $encoding)
        try {
          for ($lineIndex = 0; $lineIndex -lt $csvLines.Count; $lineIndex++) {
            $writer.WriteLine($csvLines[$lineIndex])
          }
          $writer.Flush()
          $stream.Flush($true)
        } finally {
          if ($null -ne $writer) { $writer.Dispose() }
        }
      } finally {
        if ($null -ne $stream) { $stream.Dispose() }
      }
      return
    } catch [System.IO.IOException] {
      if ($attempt -eq $MaxAttempts) { throw }
      Write-Warning "Roster '$Path' is busy; retrying update ($attempt/$MaxAttempts)."
      Start-Sleep -Seconds $RetryDelaySeconds
    }
  }
}

function Get-TenantDomain {
  param([string]$ExplicitDomain)

  if ($ExplicitDomain) { return $ExplicitDomain.Trim() }

  # Authoritative: Microsoft Graph default-domain lookup. Works across az CLI versions.
  $domain = Invoke-AzQuiet { az rest --method get --url 'https://graph.microsoft.com/v1.0/domains' --query "value[?isDefault].id | [0]" -o tsv }
  if ($LASTEXITCODE -eq 0 -and $domain) { return $domain.Trim() }

  # Newer az CLI (2.71+) exposes tenantDefaultDomain directly.
  $domain = Invoke-AzQuiet { az account show --query tenantDefaultDomain -o tsv }
  if ($LASTEXITCODE -eq 0 -and $domain) { return $domain.Trim() }

  # Fallback: trainer's UPN suffix. Correct unless the tenant default domain
  # differs from the signed-in user's UPN domain (rare for workshop accounts).
  $userName = Invoke-AzQuiet { az account show --query 'user.name' -o tsv }
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

if ($StartStudentNumber -gt $StudentCount) {
  throw '-StartStudentNumber must be less than or equal to -StudentCount.'
}

if ($SubscriptionId) {
  az account set --subscription $SubscriptionId --only-show-errors
  Assert-LastAzCommand -FailureMessage "Failed to select subscription '$SubscriptionId'."
}

$activeSubscriptionId = (& az account show --query id -o tsv).Trim()
Assert-LastAzCommand -FailureMessage 'Failed to read the active az subscription id. Run az login first.'

$tenantDomain = Get-TenantDomain -ExplicitDomain $TenantDomain
if ($LabId) {
  # Reuse a trainer-supplied lab identifier so new students join the same batch
  # (same tag value, same roster naming) as an earlier run, and Start-LabVms.ps1
  # can start everyone tagged with it later.
  $batchId = $LabId
  $batchShort = $LabId.Substring(0, [Math]::Min(20, $LabId.Length))
} else {
  # Seconds resolution avoids UPN/resource-group collisions between runs started in the same minute.
  $batchId = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
  # Short, sortable prefix for Entra display names: groups users from the same
  # batch together when the directory's display-name column is sorted.
  $batchShort = '{0}-{1}' -f $batchId.Substring(4, 4), $batchId.Substring(8, 4)
}
$csvPath = Join-Path $OutputDirectory "students-$batchId.csv"
$results = New-Object System.Collections.Generic.List[object]
$mirroringRbacFailures = New-Object System.Collections.Generic.List[string]

if (@($SharedFabric, $NoFabric, $PerStudentFabric).Where({ $_ }).Count -gt 1) {
  throw '-SharedFabric, -NoFabric, and -PerStudentFabric are mutually exclusive.'
}

$sharedFabricCapacityId = $null
if ($SharedFabric) {
  $sharedFabricCapacityId = (Invoke-AzQuiet {
    az resource show `
      --resource-group $SharedFabricResourceGroup `
      --name $SharedFabricCapacityName `
      --resource-type 'Microsoft.Fabric/capacities' `
      --query id -o tsv
  }).Trim()
  if ($LASTEXITCODE -ne 0 -or -not $sharedFabricCapacityId) {
    throw "Shared Fabric capacity '$SharedFabricCapacityName' not found in resource group '$SharedFabricResourceGroup'. Run provision-shared-fabric.ps1 first."
  }
}

Write-Output "Provisioning $StudentCount student environment(s)."
Write-Output "  Lab ID (batch): $batchId$(if ($LabId) { ' (reused)' } else { ' (generated)' })"
Write-Output "  Tenant domain: $tenantDomain"
Write-Output "  Location:      $Location"
Write-Output "  Database mode: $(if ($IsDocDB) { 'DocumentDB' } else { 'Cosmos DB for NoSQL' })"
Write-Output "  Parallelism:   $MaxParallelDeployments deployment(s)"
Write-Output "  VM power:      $(if ($SkipDeallocate) { 'left running after deployment' } else { 'deallocated after deployment; start with Set-LabVmPowerState.ps1 -LabId ' + $batchId + ' -Action Start' })"
if ($NoFabric) {
  Write-Output "  Fabric mode:   none (skipped)"
} elseif ($SharedFabric) {
  Write-Output "  Fabric mode:   shared ($SharedFabricCapacityName in $SharedFabricResourceGroup)"
} elseif ($PerStudentFabric) {
  Write-Output "  Fabric mode:   per-student (F2 by default)"
} else {
  Write-Output "  Fabric mode:   none (default; use -SharedFabric or -PerStudentFabric for Lab 4B)"
}
Write-Output ""

for ($batchStart = $StartStudentNumber; $batchStart -le $StudentCount; $batchStart += $MaxParallelDeployments) {
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
  $existingRosterRow = $null
  if (Test-Path $csvPath) {
    $existingRosterRow = @((Import-Csv $csvPath) | Where-Object { $_.UserPrincipalName -eq $studentUpn } | Select-Object -First 1)[0]
  }
  $studentPassword = if ($existingRosterRow -and $existingRosterRow.TempPassword) { $existingRosterRow.TempPassword } else { New-RandomPassword }
  $vmAdminPassword = if ($existingRosterRow -and $existingRosterRow.VmAdminPassword) { $existingRosterRow.VmAdminPassword } else { New-RandomPassword }
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

  # Reusing -LabId can hit a student already created by a prior partial run; reuse it instead of failing.
  $existingStudentObjectId = (Invoke-AzQuiet { az ad user show --id $studentUpn --query id -o tsv }).Trim()
  if ($LASTEXITCODE -eq 0 -and $existingStudentObjectId) {
    Write-Output "[$studentLabel] Entra user $studentUpn already exists from a previous run; reusing it."
    $studentObjectId = $existingStudentObjectId
  } else {
    Write-Output "[$studentLabel] creating Entra user $studentUpn"
    Invoke-AzWithRetry -FailureMessage "Failed to create Entra user '$studentUpn'." -ScriptBlock {
      az ad user create `
        --display-name $studentDisplayName `
        --user-principal-name $studentUpn `
        --password="$studentPassword" `
        --force-change-password-next-sign-in false `
        --mail-nickname $studentAlias `
        --only-show-errors | Out-Null
    }

    $studentObjectId = (Invoke-AzQuiet { az ad user show --id $studentUpn --query id -o tsv }).Trim()
    Assert-LastAzCommand -FailureMessage "Failed to read object ID for user '$studentUpn'."
    if (-not $studentObjectId) {
      throw "Created student user but could not resolve the object ID for $studentUpn."
    }
  }

  $row = [ordered]@{
    UserPrincipalName = $studentUpn
    TempPassword = $studentPassword
    BastionUri = ''
    Student = $studentLabel
    ObjectId = $studentObjectId
    ResourceGroup = $resourceGroupName
    VmName = ''
    VmComputerName = $vmComputerName
    VmPublicIp = ''
    VmPublicFqdn = ''
    BastionName = ''
    VmAdminUsername = $vmAdminUser
    VmAdminPassword = ''
    CosmosServerlessAccount = ''
    CosmosProvisionedAccount = ''
    DocumentDbCluster = ''
    FoundryAccount = ''
    StorageAccount = ''
    EnvName = $envName
    BatchId = $batchId
    Status = 'Preparing'
    StatusMessage = 'Entra user created'
    LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')
  }
  if ($SharedFabric) {
    $row.FabricSharedCapacityId = $sharedFabricCapacityId
    $row.FabricSharedCapacityName = $SharedFabricCapacityName
    $row.FabricWorkspaceId = ''
    $row.FabricWorkspaceName = ''
  }
  $rowObject = [pscustomobject]$row
  Set-CsvRowWithRetry -Path $csvPath -InputObject $rowObject -KeyProperty 'UserPrincipalName'

  $deployParams = @(
    '--location', $Location,
    '--name', $deploymentName,
    '--parameters', $BicepparamFile,
    '--parameters', "envName=$envName",
    '--parameters', "location=$Location",
    '--parameters', "resourceGroupName=$resourceGroupName",
    '--parameters', "vmAdminUsername=$vmAdminUser",
    '--parameters', "vmAdminPassword=$vmAdminPassword",
    '--parameters', 'applyVmSecurityType=true',
    '--parameters', "vmComputerName=$vmComputerName",
    '--parameters', "studentOwnerObjectId=$studentObjectId",
    '--parameters', "isDocDB=$($IsDocDB.ToString().ToLowerInvariant())",
    '--parameters', "tags=@$tagsFile",
    '--parameters', "fabricAdminMembers=@$fabricMembersFile"
  )
  if ($PerStudentFabric) {
    $deployParams += @('--parameters', 'deployFabric=true')
  } else {
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
    $rowObject.Status = 'Failed'
    $rowObject.StatusMessage = "What-if failed for ARM deployment $deploymentName"
    $rowObject.LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')
    Set-CsvRowWithRetry -Path $csvPath -InputObject $rowObject -KeyProperty 'UserPrincipalName'
    Write-Warning "[$studentLabel] what-if failed; deleting newly created Entra user $studentUpn"
    az ad user delete --id $studentUpn --only-show-errors
    throw "What-if failed for deployment '$deploymentName'."
  }

    Write-Output "[$studentLabel] starting deployment $deploymentName"
    # Re-running with the same -LabId can hit a deployment already started by a prior
    # run (e.g. left in-flight after an earlier failure); reattach instead of re-creating.
    $existingDeploymentState = (Invoke-AzQuiet { az deployment sub show --name $deploymentName --query properties.provisioningState -o tsv }).Trim()
    $existingDeploymentFound = $LASTEXITCODE -eq 0 -and $existingDeploymentState
    if ($existingDeploymentFound -and $existingDeploymentState -in @('Accepted', 'Running')) {
      Write-Output "[$studentLabel] deployment $deploymentName is already active from a previous run; resuming wait instead of restarting."
    } elseif ($existingDeploymentFound -and $existingDeploymentState -eq 'Succeeded') {
      Write-Output "[$studentLabel] deployment $deploymentName already succeeded from a previous run; reusing its outputs."
    } else {
      az deployment sub create @deployParams --no-wait --only-show-errors | Out-Null
      if ($LASTEXITCODE -ne 0) {
        $rowObject.Status = 'Failed'
        $rowObject.StatusMessage = "Failed to start ARM deployment $deploymentName"
        $rowObject.LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')
        Set-CsvRowWithRetry -Path $csvPath -InputObject $rowObject -KeyProperty 'UserPrincipalName'
        Assert-LastAzCommand -FailureMessage "Failed to start deployment '$deploymentName'."
      }
    }

    $rowObject.Status = 'Deploying'
    $rowObject.StatusMessage = "ARM deployment $deploymentName is running"
    $rowObject.LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')
    Set-CsvRowWithRetry -Path $csvPath -InputObject $rowObject -KeyProperty 'UserPrincipalName'

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
      RosterRow = $rowObject
      WaitDeadlineUtc = [DateTime]::UtcNow.AddSeconds(7200)
    }) | Out-Null
  }

  Write-Output "Waiting for deployment batch $batchStart-$batchEnd."
  while ($pendingDeployments.Count -gt 0) {
    $pendingDeployment = $null
    $deploymentState = $null
    $failedDeployment = $null
    $failedDeploymentState = $null

    foreach ($candidate in $pendingDeployments) {
      $candidateState = (Invoke-AzQuiet { az deployment sub show --name $candidate.DeploymentName --query properties.provisioningState -o tsv })
      $stateQuerySucceeded = $LASTEXITCODE -eq 0
      $candidateState = $candidateState.Trim()

      if ($stateQuerySucceeded -and $candidateState -eq 'Succeeded') {
        $pendingDeployment = $candidate
        $deploymentState = $candidateState
        break
      }
      if ($stateQuerySucceeded -and $candidateState -in @('Failed', 'Canceled') -and $null -eq $failedDeployment) {
        $failedDeployment = $candidate
        $failedDeploymentState = $candidateState
      } elseif ([DateTime]::UtcNow -ge $candidate.WaitDeadlineUtc -and $null -eq $failedDeployment) {
        $failedDeployment = $candidate
        $failedDeploymentState = 'TimedOut'
      }
    }

    if ($null -eq $pendingDeployment) {
      $pendingDeployment = $failedDeployment
      $deploymentState = $failedDeploymentState
    }
    if ($null -eq $pendingDeployment) {
      Start-Sleep -Seconds 15
      continue
    }

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
    $rowObject = $pendingDeployment.RosterRow

    # The asynchronous launch is attempt 1. Retry transient ARM failures synchronously
    # against the same deployment and resource group so ARM resumes from current state.
    if ($deploymentState -ne 'Succeeded') {
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
      if ($LASTEXITCODE -ne 0) {
        $rowObject.Status = 'Failed'
        $rowObject.StatusMessage = "ARM deployment $deploymentName failed after $deploymentAttempts attempts"
        $rowObject.LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')
        Set-CsvRowWithRetry -Path $csvPath -InputObject $rowObject -KeyProperty 'UserPrincipalName'
        Assert-LastAzCommand -FailureMessage "Deployment '$deploymentName' failed after $deploymentAttempts attempts."
      }
    }

  $outputsJson = az deployment sub show --name $deploymentName --query properties.outputs -o json
  Assert-LastAzCommand -FailureMessage "Failed to read outputs for deployment '$deploymentName'."
  $outputs = $outputsJson | ConvertFrom-Json

  $rowObject.Status = 'Finalizing'
  $rowObject.StatusMessage = 'Deployment succeeded; creating the Bastion shareable link'
  $rowObject.LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')
  Set-CsvRowWithRetry -Path $csvPath -InputObject $rowObject -KeyProperty 'UserPrincipalName'

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

  $rowObject.VmName = $outputs.vmName.value
  $rowObject.VmPublicIp = $outputs.vmPublicIpAddress.value
  $rowObject.VmPublicFqdn = $outputs.vmPublicIp.value
  $rowObject.BastionName = $outputs.bastionName.value
  $rowObject.BastionUri = $bastionUri
  $rowObject.VmAdminPassword = $vmAdminPassword
  $rowObject.CosmosServerlessAccount = $outputs.cosmosAccountName.value
  $rowObject.CosmosProvisionedAccount = $outputs.cosmosProvisionedAccountName.value
  $rowObject.DocumentDbCluster = $outputs.documentDbClusterName.value
  $rowObject.FoundryAccount = $outputs.foundryAccountName.value
  $rowObject.StorageAccount = $outputs.storageAccountName.value
  $rowObject.Status = 'Ready'
  $rowObject.StatusMessage = 'Deployment and Bastion shareable link completed'
  $rowObject.LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')
  $results.Add($rowObject)
  Write-Output "[$studentLabel] Bastion shareable URL: $($rowObject.BastionUri)"

  Set-CsvRowWithRetry -Path $csvPath -InputObject $rowObject -KeyProperty 'UserPrincipalName'

  if (-not $SkipDeallocate) {
    # Land the VM in a deallocated (non-billed) state right after it is created.
    # Start-LabVms.ps1 / Set-LabVmPowerState.ps1 -Action Start brings the whole batch up on class day.
    Write-Output "[$studentLabel] deallocating VM $($outputs.vmName.value)"
    az vm deallocate --resource-group $resourceGroupName --name $outputs.vmName.value --no-wait --only-show-errors
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "[$studentLabel] Failed to request deallocation for VM $($outputs.vmName.value). Deallocate manually before class."
    }
  }

  $pendingDeployments.Remove($pendingDeployment) | Out-Null
  }
}

Write-Output ""
Write-Output "Provisioned $($results.Count) student environment(s)."
Write-Output "Roster written to: $csvPath"
if (-not $SkipDeallocate) {
  Write-Output "VMs were deallocated after creation. Start them for class with:"
  Write-Output "  ./script/Set-LabVmPowerState.ps1 -LabId $batchId -Action Start"
}
if ($mirroringRbacFailures.Count -gt 0) {
  Write-Warning "Cosmos mirroring RBAC failed for $($mirroringRbacFailures.Count) student(s): $($mirroringRbacFailures -join ', '). Re-apply with script/Set-CosmosMirroringRbac.ps1 before Lab 4B."
}
$results | Format-Table Student, UserPrincipalName, ResourceGroup, VmPublicFqdn, VmAdminUsername -AutoSize
