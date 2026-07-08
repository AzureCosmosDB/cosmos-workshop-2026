# Lab VM Setup

Manual steps needed on a new lab VM to support the lab content. Based on VM image configured in bicep.

```json
imageReference: {
    publisher: 'microsoftvisualstudio'
    offer: 'windowsplustools'
    sku: 'base-win11-gen2'
    version: 'latest'
}
```

Steps marked _(script)_ are handled by [`script/Initialize-LabVm.ps1`](../script/Initialize-LabVm.ps1) that installs these parts in one step. Safe to re-run in case of failures.

- Click through privacy-preferences dialogs on first login.
- Install .NET 10 SDK: _(script)_
  - `winget install Microsoft.DotNet.SDK.10`
  - Accept Microsoft Store terms when prompted by first run of winget.
- Install Python: _(script)_
  - `winget install Python.Python.3.14`
  - `python.exe -m pip install --upgrade pip`
  - `pip install ipykernel azure-cosmos azure-identity python-dotenv openai numpy`
  - `pip install` packages are called out in individual labs but preinstall can save time.
- Launch VS Code:
  - Prompt to Sign in to GitHub when prompted - dismiss since students will use AZ accounts only
  - Install extensions: **Jupyter**, **C#**, **Python**. _(script)_
- WSL update popup: press **Enter** to install. (Cancel just re-opens the popup later)
  - WSL itself is not used by any lab but update keeps it from popping back up.
