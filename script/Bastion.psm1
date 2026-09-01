# Bastion.psm1
# Purpose: Create and retrieve Azure Bastion shareable links.

function Invoke-AzRestQuiet {
  # $ErrorActionPreference='Stop' (set by callers) promotes az's stderr/non-zero exit into a
  # terminating error even with 2>$null, which would break the retry loop below on the first
  # transient failure (e.g. Bastion/VM not fully ready yet). Temporarily relax it here instead.
  param([Parameter(Mandatory = $true)][ScriptBlock]$ScriptBlock)
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $ScriptBlock 2>$null
  } finally {
    $ErrorActionPreference = $prevEap
  }
}

function Get-BastionShareableLink {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BastionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VmId,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 120)]
    [int]$MaxAttempts = 60,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 60)]
    [int]$DelaySeconds = 10
  )

  $apiVersion = '2023-05-01'
  $baseUrl = "https://management.azure.com$BastionId"
  $getUrl = "$baseUrl/getShareableLinks?api-version=$apiVersion"
  $createUrl = "$baseUrl/createShareableLinks?api-version=$apiVersion"
  $requestFile = [System.IO.Path]::GetTempFileName()

  try {
    $requestJson = @{
      vms = @(
        @{
          vm = @{ id = $VmId }
        }
      )
    } | ConvertTo-Json -Depth 5 -Compress
    [System.IO.File]::WriteAllText(
      $requestFile,
      $requestJson,
      [System.Text.UTF8Encoding]::new($false)
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
      $getResponseJson = Invoke-AzRestQuiet { az rest --method post --url $getUrl --body "@$requestFile" --only-show-errors }
      if ($LASTEXITCODE -eq 0 -and $getResponseJson) {
        $getResponse = $getResponseJson | ConvertFrom-Json
        $existingLink = @($getResponse.value) |
          Where-Object { $_.vm.id -eq $VmId -and $_.bsl } |
          Select-Object -First 1
        if ($existingLink) {
          return [string]$existingLink.bsl
        }
      }

      $createResponseJson = Invoke-AzRestQuiet { az rest --method post --url $createUrl --body "@$requestFile" --only-show-errors }
      if ($LASTEXITCODE -eq 0 -and $createResponseJson) {
        $createResponse = $createResponseJson | ConvertFrom-Json
        $createdLink = @($createResponse.value) |
          Where-Object { $_.vm.id -eq $VmId -and $_.bsl } |
          Select-Object -First 1
        if ($createdLink) {
          return [string]$createdLink.bsl
        }
      }

      Start-Sleep -Seconds $DelaySeconds
    }

    throw "Timed out waiting for the Bastion shareable link for VM '$VmId'."
  }
  finally {
    Remove-Item -Path $requestFile -Force -ErrorAction SilentlyContinue
  }
}

Export-ModuleMember -Function @('Get-BastionShareableLink')