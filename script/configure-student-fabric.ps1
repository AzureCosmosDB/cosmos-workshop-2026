param(
  [Parameter(Mandatory = $true)][string]$RosterCsv,
  [Parameter(Mandatory = $false)][string]$CapacityDisplayName = 'fabricworkshopshared',
  [Parameter(Mandatory = $false)][string]$WorkspaceNamePrefix = 'lab-ws'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Fabric.psm1') -Force

if (-not (Test-Path $RosterCsv)) { throw "Roster CSV not found: $RosterCsv" }

$token = Get-FabricAccessToken
$capacityId = Get-FabricCapacityIdByName -Token $token -DisplayName $CapacityDisplayName

$roster = @(Import-Csv -Path $RosterCsv)
if ($roster.Count -eq 0) { throw "Roster CSV is empty: $RosterCsv" }

foreach ($row in $roster) {
  if ($row.PSObject.Properties.Name -notcontains 'FabricWorkspaceId') {
    $row | Add-Member -NotePropertyName 'FabricWorkspaceId' -NotePropertyValue ''
  }
  if ($row.PSObject.Properties.Name -notcontains 'FabricWorkspaceName') {
    $row | Add-Member -NotePropertyName 'FabricWorkspaceName' -NotePropertyValue ''
  }
}

$failureCount = 0
$successCount = 0

foreach ($row in $roster) {
  if (-not $row.BatchId) {
    throw "Roster row for '$($row.Student)' is missing BatchId. Re-run provisioning with the current script to regenerate the roster."
  }
  $workspaceName = "$WorkspaceNamePrefix-$($row.VmAdminUsername)-$($row.BatchId)"
  $description = "Workshop workspace for $($row.Student) ($($row.UserPrincipalName))."

  Write-Output "[$($row.Student)] creating workspace $workspaceName"
  try {
    $workspace = New-FabricStudentWorkspace `
      -Token $token `
      -DisplayName $workspaceName `
      -CapacityId $capacityId `
      -StudentObjectId $row.ObjectId `
      -Description $description
    $row.FabricWorkspaceId = $workspace.id
    $row.FabricWorkspaceName = $workspace.displayName
    $successCount++
  } catch {
    Write-Warning "[$($row.Student)] workspace setup failed: $($_.Exception.Message)"
    $failureCount++
  }
}

$roster | Export-Csv -Path $RosterCsv -NoTypeInformation -Encoding UTF8

Write-Output ""
Write-Output "Configured $successCount workspace(s). Failures: $failureCount."
Write-Output "Roster updated in place: $RosterCsv"

if ($failureCount -gt 0) {
  Write-Output "Re-run this script to retry failed students (the script is idempotent on workspace name)."
  exit $failureCount
}
