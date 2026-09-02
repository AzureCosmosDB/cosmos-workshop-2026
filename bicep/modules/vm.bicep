// vm.bicep - Lab VM definition
targetScope = 'resourceGroup'

@description('Location for the VM')
param location string

@description('Name of the VM resource')
param vmName string

@description('Computer name for the VM OS profile')
param vmComputerName string

@description('VM size')
param vmSize string

@description('Disk controller type - use NVMe for v5/v6 series sizes that support it')
param diskControllerType string = 'SCSI'

@description('VM admin username')
param adminUsername string

@description('VM admin password')
@minLength(12)
@secure()
param adminPassword string

@description('Entra object ID to grant Windows VM sign-in access.')
param entraLoginObjectId string

var vmUserLoginRoleDefinitionId = 'fb879df8-f326-4884-b1cf-06f3ad86be52'

@description('NIC resource ID to attach to the VM')
param nicId string

@description('Tags applied to the VM')
param tags object

@description('Set to true when creating a VM so securityType is stamped; set false for no-op reruns to avoid immutable property updates')
param applyVmSecurityType bool = true

@description('Install Azure DocumentDB extensions and MongoDB command-line tools')
param isDocDB bool = false

var vmPropertiesBase = {
  hardwareProfile: {
    vmSize: vmSize
  }
  storageProfile: {
    diskControllerType: diskControllerType
    osDisk: {
      createOption: 'fromImage'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
      deleteOption: 'Delete'
    }
    imageReference: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'windows-11'
      sku: 'win11-24h2-ent'
      version: 'latest'
    }
  }
  networkProfile: {
    networkInterfaces: [
      {
        id: nicId
        properties: {
          deleteOption: 'Detach'
        }
      }
    ]
  }
  additionalCapabilities: {
    hibernationEnabled: false
  }
  osProfile: {
    computerName: vmComputerName
    adminUsername: adminUsername
    adminPassword: adminPassword
    windowsConfiguration: {
      enableAutomaticUpdates: true
      provisionVMAgent: true
      patchSettings: {
        patchMode: 'AutomaticByOS'
        assessmentMode: 'ImageDefault'
        enableHotpatching: false
      }
    }
  }
  diagnosticsProfile: {
    bootDiagnostics: {
      enabled: true
    }
  }
}

var vmSecurityProfile = applyVmSecurityType ? {
  securityProfile: {
    securityType: 'TrustedLaunch'
    uefiSettings: {
      secureBootEnabled: true
      vTpmEnabled: true
    }
  }
} : {}
var initializerScript = loadTextContent('../../script/Initialize-LabVm.ps1')

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: union(vmPropertiesBase, vmSecurityProfile)
}

resource entraLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: virtualMachine
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.2'
    autoUpgradeMinorVersion: true
  }
}

resource entraLoginRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(entraLoginObjectId)) {
  name: guid(virtualMachine.id, entraLoginObjectId, vmUserLoginRoleDefinitionId)
  scope: virtualMachine
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmUserLoginRoleDefinitionId)
    principalId: entraLoginObjectId
    principalType: 'User'
  }
}

resource initializeLabVm 'Microsoft.Compute/virtualMachines/runCommands@2024-11-01' = {
  parent: virtualMachine
  name: 'InitializeLabVm'
  location: location
  properties: {
    source: {
      script: replace(replace(replace('''
        $ErrorActionPreference = 'Stop'
        $setupRoot = 'C:\LabSetup'
        $setupScript = Join-Path $setupRoot 'Initialize-LabVm.ps1'
        New-Item -ItemType Directory -Path $setupRoot -Force | Out-Null
        [System.IO.File]::WriteAllBytes($setupScript, [Convert]::FromBase64String('__INITIALIZER_BASE64__'))

        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setupScript -SetupPhase Machine -IsDocDB __IS_DOCDB__
        if ($LASTEXITCODE -ne 0) { throw "Machine setup failed with exit code $LASTEXITCODE." }

        $entraSetupAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$setupScript`" -SetupPhase User -IsDocDB __IS_DOCDB__ -SetupTaskName InitializeEntraUser"
        $entraSetupTrigger = New-ScheduledTaskTrigger -AtLogOn
        $entraSetupPrincipal = New-ScheduledTaskPrincipal -GroupId 'BUILTIN\Users' -RunLevel Limited
        Register-ScheduledTask -TaskName InitializeEntraUser -Action $entraSetupAction -Trigger $entraSetupTrigger -Principal $entraSetupPrincipal -Force | Out-Null
        Unregister-ScheduledTask -TaskName InitializeLabVm -Confirm:$false -ErrorAction SilentlyContinue
      ''', '__INITIALIZER_BASE64__', base64(initializerScript)), '__ADMIN_USERNAME__', adminUsername), '__IS_DOCDB__', string(isDocDB ? 1 : 0))
    }
    timeoutInSeconds: 7200
    asyncExecution: false
    treatFailureAsDeploymentFailure: true
  }
}

output vmId string = virtualMachine.id
output vmNameOut string = virtualMachine.name
