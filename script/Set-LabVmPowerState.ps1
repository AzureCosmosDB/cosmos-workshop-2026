param(
  [Parameter(Mandatory = $true)]
  [string]$LabId,

  [Parameter(Mandatory = $true)]
  [ValidateSet('Start', 'Deallocate')]
  [string]$Action,

  [Parameter(Mandatory = $false)]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $false)]
  [switch]$Wait
)

$ErrorActionPreference = 'Stop'

if ($SubscriptionId) {
  az account set --subscription $SubscriptionId --only-show-errors
  if ($LASTEXITCODE -ne 0) { throw "Failed to select subscription '$SubscriptionId'." }
}

$vmsJson = az vm list --query "[?tags.batch=='$LabId'].{rg:resourceGroup, name:name}" -o json --only-show-errors
if ($LASTEXITCODE -ne 0) { throw "Failed to list VMs tagged batch='$LabId'." }

$vms = @($vmsJson | ConvertFrom-Json)
if ($vms.Count -eq 0) {
  throw "No VMs found tagged batch='$LabId'. Confirm the lab identifier matches -LabId (or the auto-generated batch id) used at provisioning time."
}

$azAction = if ($Action -eq 'Start') { 'start' } else { 'deallocate' }
Write-Output "$Action`ing $($vms.Count) VM(s) for lab '$LabId'."

$failures = New-Object System.Collections.Generic.List[string]
foreach ($vm in $vms) {
  Write-Output "  $($vm.rg)/$($vm.name)"
  $azArgs = @('vm', $azAction, '--resource-group', $vm.rg, '--name', $vm.name, '--only-show-errors')
  if (-not $Wait) { $azArgs += '--no-wait' }

  az @azArgs | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "  Failed to $azAction $($vm.rg)/$($vm.name)."
    $failures.Add("$($vm.rg)/$($vm.name)") | Out-Null
  }
}

if ($failures.Count -gt 0) {
  throw "$Action failed for $($failures.Count) VM(s): $($failures -join ', ')"
}

if ($Wait) {
  Write-Output "Done. All $($vms.Count) VM(s) confirmed $($azAction)d."
} else {
  Write-Output "Requested $azAction for $($vms.Count) VM(s) without waiting. Check the Azure portal or 'az vm list' for current power state."
}
