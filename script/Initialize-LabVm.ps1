$ErrorActionPreference = 'Stop'

function Update-PathFromRegistry {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

function Invoke-Winget {
  param([Parameter(Mandatory)][string]$Id)

  Write-Host "==> winget install $Id" -ForegroundColor Cyan
  winget install --id $Id --exact --silent `
    --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
    # -1978335189 = APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE (already installed/up to date)
    throw "winget install '$Id' failed with exit code $LASTEXITCODE."
  }
  Update-PathFromRegistry
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget is not available on PATH. Install App Installer from the Microsoft Store and retry."
}

Invoke-Winget -Id 'Microsoft.DotNet.SDK.10'

Invoke-Winget -Id 'Python.Python.3.14'

Invoke-Winget -Id 'Microsoft.VisualStudioCode'

$python = (Get-Command python.exe -ErrorAction SilentlyContinue)?.Source
if (-not $python) { throw "python.exe not found on PATH after install." }

Write-Host "==> Upgrading pip" -ForegroundColor Cyan
& $python -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed." }

Write-Host "==> Installing lab pip packages" -ForegroundColor Cyan
& $python -m pip install ipykernel azure-cosmos azure-identity python-dotenv openai numpy
if ($LASTEXITCODE -ne 0) { throw "pip install failed." }

$code = (Get-Command code.cmd -ErrorAction SilentlyContinue)?.Source
if (-not $code) { $code = (Get-Command code -ErrorAction SilentlyContinue)?.Source }
if (-not $code) {
  throw "VS Code CLI ('code') not found on PATH after install."
}
else {
  foreach ($ext in @('ms-toolsai.jupyter', 'ms-dotnettools.csharp', 'ms-python.python')) {
    Write-Host "==> code --install-extension $ext" -ForegroundColor Cyan
    & $code --install-extension $ext --force
    if ($LASTEXITCODE -ne 0) { throw "Failed to install VS Code extension '$ext'." }
  }
}

Write-Host ""
Write-Host "Lab VM setup complete." -ForegroundColor Green
Write-Host "Remaining manual steps (cannot be automated reliably):" -ForegroundColor Yellow
Write-Host "  - Dismiss the VS Code 'Sign in to GitHub' prompt (students use Azure accounts)."
Write-Host "  - If a WSL update popup appears, press Enter to install."
