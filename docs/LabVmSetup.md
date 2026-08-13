---
title: Lab VM Setup
description: Configure the Windows 11 lab VM with the SDKs, tools, and VS Code extensions required by the workshop.
---

Manual steps needed on a new lab VM to support the lab content. Based on the VM image configured in Bicep.

```bicep
imageReference: {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'windows-11'
  sku: 'win11-24h2-ent'
  version: 'latest'
}
```

The VM deployment runs [`script/Initialize-LabVm.ps1`](../script/Initialize-LabVm.ps1) as the local VM administrator. The script is safe to rerun if setup fails.

- Click through privacy-preferences dialogs on first login.
- Install PowerShell 7, Azure CLI, and Git. _(script)_
- Install .NET 10 SDK: _(script)_
  - `winget install Microsoft.DotNet.SDK.10`
  - Accept Microsoft Store terms when prompted by first run of winget.
- Install Python: _(script)_
  - `winget install Python.Python.3.14`
  - `python.exe -m pip install --upgrade pip`
  - `pip install ipykernel azure-cosmos azure-identity python-dotenv openai numpy`
  - `pip install` packages are called out in individual labs but preinstall can save time.
- Install and launch VS Code: _(script)_
  - `winget install Microsoft.VisualStudioCode`
  - Prompt to Sign in to GitHub when prompted - dismiss since students will use AZ accounts only
  - Install extensions: **Jupyter**, **C#**, **Python**. _(script)_
- Clone the workshop repository to `Documents\cosmos-workshop-2026`. _(script)_
- Use PowerShell 7 for the workshop. Git Bash is not required.
- WSL update popup: press **Enter** to install. (Cancel just re-opens the popup later)
  - WSL itself is not used by any lab but update keeps it from popping back up.
