[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$RepositoryUrl = 'https://github.com/AzureCosmosDB/cosmos-workshop-2026.git',

  [Parameter(Mandatory = $false)]
  [string]$RepositoryPath = '',

  [Parameter(Mandatory = $false)]
  [string]$UserHomePath = '',

  [Parameter(Mandatory = $false)]
  [string]$SetupTaskName,

  [Parameter(Mandatory = $false)]
  [ValidateSet('All', 'Machine', 'User')]
  [string]$SetupPhase = 'All'
)

$ErrorActionPreference = 'Stop'

function Update-PathFromRegistry {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

function Invoke-Chocolatey {
  param([Parameter(Mandatory)][string]$Package)

  Write-Host "==> choco install $Package" -ForegroundColor Cyan
  & choco.exe install $Package --yes --no-progress --limit-output
  if ($LASTEXITCODE -ne 0) {
    throw "choco install '$Package' failed with exit code $LASTEXITCODE."
  }
  Update-PathFromRegistry
}

if ($SetupPhase -in @('All', 'Machine')) {
  if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    Write-Host '==> Installing Chocolatey' -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    $installScript = (New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
    & ([scriptblock]::Create($installScript))
    Update-PathFromRegistry
  }

  Invoke-Chocolatey -Package 'powershell-core'
  Invoke-Chocolatey -Package 'azure-cli'
  Invoke-Chocolatey -Package 'git'
  Invoke-Chocolatey -Package 'dotnet-10.0-sdk'
  Invoke-Chocolatey -Package 'python314'
  Invoke-Chocolatey -Package 'vscode'
}

if ($SetupPhase -eq 'Machine') {
  Write-Host "Lab VM machine setup complete." -ForegroundColor Green
  exit 0
}

Update-PathFromRegistry

if (-not $RepositoryPath) {
  $documentsPath = [Environment]::GetFolderPath('MyDocuments')
  if (-not $documentsPath) { throw 'Unable to resolve the current user Documents folder.' }
  $RepositoryPath = Join-Path $documentsPath 'cosmos-workshop-2026'
}

if (-not $UserHomePath) {
  $UserHomePath = Split-Path (Split-Path $RepositoryPath -Parent) -Parent
}

$git = Get-Command git.exe -ErrorAction SilentlyContinue
if (-not $git) { throw "git.exe not found on PATH after install." }

if (Test-Path (Join-Path $RepositoryPath '.git')) {
  Write-Host "==> Workshop repository already exists at $RepositoryPath" -ForegroundColor Cyan
}
elseif (Test-Path $RepositoryPath) {
  throw "Repository path exists but is not a Git repository: $RepositoryPath"
}
else {
  $repositoryParent = Split-Path -Parent $RepositoryPath
  New-Item -ItemType Directory -Path $repositoryParent -Force | Out-Null
  Write-Host "==> Cloning workshop repository to $RepositoryPath" -ForegroundColor Cyan
  & $git clone $RepositoryUrl $RepositoryPath
  if ($LASTEXITCODE -ne 0) { throw "Git clone failed with exit code $LASTEXITCODE." }
}

$pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
$python = if ($pythonCommand) { $pythonCommand.Source } else { $null }
if (-not $python) { throw "python.exe not found on PATH after install." }

Write-Host "==> Upgrading pip" -ForegroundColor Cyan
& $python -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed." }

Write-Host "==> Installing lab pip packages" -ForegroundColor Cyan
& $python -m pip install ipykernel azure-cosmos azure-identity python-dotenv openai numpy
if ($LASTEXITCODE -ne 0) { throw "pip install failed." }

$codeCommand = Get-Command code.cmd -ErrorAction SilentlyContinue
if (-not $codeCommand) { $codeCommand = Get-Command code -ErrorAction SilentlyContinue }
$code = if ($codeCommand) { $codeCommand.Source } else { $null }
if (-not $code) {
  throw "VS Code CLI ('code') not found on PATH after install."
}
else {
  $extensionsPath = Join-Path $UserHomePath '.vscode\extensions'
  foreach ($ext in @('ms-toolsai.jupyter', 'ms-dotnettools.csharp', 'ms-python.python')) {
    Write-Host "==> code --install-extension $ext" -ForegroundColor Cyan
    & $code --extensions-dir $extensionsPath --install-extension $ext --force
    if ($LASTEXITCODE -ne 0) { throw "Failed to install VS Code extension '$ext'." }
  }
}

Write-Host ""
Write-Host "Lab VM setup complete." -ForegroundColor Green
Write-Host "Workshop repository: $RepositoryPath"
Write-Host "Remaining manual steps (cannot be automated reliably):" -ForegroundColor Yellow
Write-Host "  - Open PowerShell 7, then run: az login"
Write-Host "  - Change to $RepositoryPath and run: ./SetEnv.ps1"
Write-Host "  - Dismiss the VS Code 'Sign in to GitHub' prompt (students use Azure accounts)."
Write-Host "  - If a WSL update popup appears, press Enter to install."

if ($SetupTaskName) {
  Unregister-ScheduledTask -TaskName $SetupTaskName -Confirm:$false -ErrorAction SilentlyContinue
}
