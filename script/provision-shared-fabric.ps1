param(
  [Parameter(Mandatory = $false)][string]$SubscriptionId,
  [Parameter(Mandatory = $false)][string]$BicepparamFile = (Join-Path $PSScriptRoot '..\bicep\shared.bicepparam'),
  [Parameter(Mandatory = $false)][string]$Location = 'westus'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $BicepparamFile)) { throw "Bicep parameter file not found: $BicepparamFile" }

if ($SubscriptionId) {
  az account set --subscription $SubscriptionId --only-show-errors
  if ($LASTEXITCODE -ne 0) { throw "Failed to select subscription '$SubscriptionId'." }
}

$deploymentName = "lab-shared-fabric-" + (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmm')

az deployment sub create `
  --location $Location `
  --name $deploymentName `
  --parameters $BicepparamFile `
  --only-show-errors | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Shared Fabric deployment '$deploymentName' failed." }

$outputs = az deployment sub show --name $deploymentName --query properties.outputs -o json | ConvertFrom-Json

Write-Output "Shared Fabric capacity deployed."
Write-Output "  Resource group: $($outputs.sharedResourceGroupName.value)"
Write-Output "  Capacity name:  $($outputs.fabricCapacityName.value)"
Write-Output "  SKU:            $($outputs.fabricCapacitySku.value)"
Write-Output "  Capacity ID:    $($outputs.fabricCapacityId.value)"
Write-Output ""
Write-Output "Pass -SharedFabric to provision-student-environments.ps1 for the next cohort to skip per-student Fabric deployment."
