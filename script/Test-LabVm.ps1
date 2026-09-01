[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$AdminUsername = 'lab_user1',

  [Parameter(Mandatory = $false)]
  [string]$DnsNames = '',

  [Parameter(Mandatory = $false)]
  [bool]$IsDocDB = $false
)

$userHome = "C:\Users\$AdminUsername"
$paths = [ordered]@{
  PowerShell7 = 'C:\Program Files\PowerShell\7\pwsh.exe'
  AzureCLI    = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
  Git         = 'C:\Program Files\Git\cmd\git.exe'
  DotNet      = 'C:\Program Files\dotnet\dotnet.exe'
  PythonMachine = 'C:\Python314\python.exe'
  VSCodeUser  = "$userHome\AppData\Local\Programs\Microsoft VS Code\Code.exe"
  VSCodeMachine = 'C:\Program Files\Microsoft VS Code\Code.exe'
}

if ($IsDocDB) {
  $paths.Node = 'C:\Program Files\nodejs\node.exe'
  $paths.MongoSh = 'C:\ProgramData\chocolatey\bin\mongosh.exe'
  $paths.MongoImport = 'C:\ProgramData\chocolatey\bin\mongoimport.exe'
}

$result = [ordered]@{}
foreach ($item in $paths.GetEnumerator()) {
  $result[$item.Key] = Test-Path $item.Value
}

$result.PythonUser = [bool](Get-ChildItem "$userHome\AppData\Local\Programs\Python\Python*\python.exe" -ErrorAction SilentlyContinue)
$result.Repository = Test-Path "$userHome\Documents\cosmos-workshop-2026\.git"

$setupTask = Get-ScheduledTask -TaskName InitializeLabVm -ErrorAction SilentlyContinue
$result.SetupTask = if ($setupTask) { $setupTask.State.ToString() } else { 'Not present (completed/self-removed)' }

$extensions = @('ms-toolsai.jupyter', 'ms-dotnettools.csharp', 'ms-python.python')
if ($IsDocDB) {
  $extensions += @(
    'ms-azuretools.vscode-documentdb',
    'ms-azurecosmosdbtools.vscode-mongo-migration'
  )
}

$result.Extensions = $extensions | ForEach-Object {
  "$_=$(Test-Path "$userHome\.vscode\extensions\$_*")"
}

$result.Dns = ($DnsNames -split ',' | Where-Object { $_ }) | ForEach-Object {
  $addresses = Resolve-DnsName $_ -Type A -ErrorAction SilentlyContinue |
    Where-Object IPAddress |
    Select-Object -ExpandProperty IPAddress
  "$_=$($addresses -join ',')"
}

[pscustomobject]$result | ConvertTo-Json -Depth 4