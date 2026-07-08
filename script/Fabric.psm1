$script:FabricApiRoot = 'https://api.fabric.microsoft.com/v1'

function Get-FabricAccessToken {
  $token = az account get-access-token --resource 'https://api.fabric.microsoft.com' --query accessToken -o tsv 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $token) {
    throw 'Failed to acquire a Fabric access token. Run az login and confirm your account has Fabric access.'
  }
  $token.Trim()
}

function Invoke-FabricRest {
  param(
    [Parameter(Mandatory)][string]$Token,
    [Parameter(Mandatory)][ValidateSet('GET','POST','PATCH','DELETE')][string]$Method,
    [Parameter(Mandatory)][string]$Path,
    [object]$Body
  )

  $headers = @{
    Authorization = "Bearer $Token"
    'Content-Type' = 'application/json'
  }
  $uri = "$script:FabricApiRoot$Path"
  $params = @{
    Method = $Method
    Uri = $uri
    Headers = $headers
    ErrorAction = 'Stop'
  }
  if ($PSBoundParameters.ContainsKey('Body')) {
    $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
  }
  Invoke-RestMethod @params
}

function Get-FabricCapacityIdByName {
  param(
    [Parameter(Mandatory)][string]$Token,
    [Parameter(Mandatory)][string]$DisplayName
  )

  $response = Invoke-FabricRest -Token $Token -Method GET -Path '/capacities'
  $match = $response.value | Where-Object { $_.displayName -eq $DisplayName } | Select-Object -First 1
  if (-not $match) {
    throw "Fabric capacity '$DisplayName' not visible to the signed-in account. Confirm the capacity exists and is assigned to your tenant."
  }
  $match.id
}

function Get-FabricWorkspaceByName {
  param(
    [Parameter(Mandatory)][string]$Token,
    [Parameter(Mandatory)][string]$DisplayName
  )

  $response = Invoke-FabricRest -Token $Token -Method GET -Path '/workspaces'
  $response.value | Where-Object { $_.displayName -eq $DisplayName } | Select-Object -First 1
}

function New-FabricStudentWorkspace {
  param(
    [Parameter(Mandatory)][string]$Token,
    [Parameter(Mandatory)][string]$DisplayName,
    [Parameter(Mandatory)][string]$CapacityId,
    [Parameter(Mandatory)][string]$StudentObjectId,
    [string]$Description = ''
  )

  $existing = Get-FabricWorkspaceByName -Token $Token -DisplayName $DisplayName
  if ($existing) {
    $workspace = $existing
  } else {
    $body = @{ displayName = $DisplayName }
    if ($Description) { $body.description = $Description }
    $workspace = Invoke-FabricRest -Token $Token -Method POST -Path '/workspaces' -Body $body
  }

  Invoke-FabricRest -Token $Token -Method POST -Path "/workspaces/$($workspace.id)/assignToCapacity" -Body @{
    capacityId = $CapacityId
  } | Out-Null

  $assignment = @{
    principal = @{ id = $StudentObjectId; type = 'User' }
    role = 'Admin'
  }
  try {
    Invoke-FabricRest -Token $Token -Method POST -Path "/workspaces/$($workspace.id)/roleAssignments" -Body $assignment | Out-Null
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 409) { throw }
  }

  $workspace
}

Export-ModuleMember -Function Get-FabricAccessToken, Get-FabricCapacityIdByName, Get-FabricWorkspaceByName, New-FabricStudentWorkspace
