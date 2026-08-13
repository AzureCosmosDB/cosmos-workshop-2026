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

@description('NIC resource ID to attach to the VM')
param nicId string

@description('Tags applied to the VM')
param tags object

@description('Set to true when creating a VM so securityType is stamped; set false for no-op reruns to avoid immutable property updates')
param applyVmSecurityType bool = true

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
    securityType: 'Standard'
  }
} : {}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location
  tags: tags
  properties: union(vmPropertiesBase, vmSecurityProfile)
}

resource initializeLabVm 'Microsoft.Compute/virtualMachines/runCommands@2024-11-01' = {
  parent: virtualMachine
  name: 'InitializeLabVm'
  location: location
  properties: {
    source: {
      script: loadTextContent('../../script/Initialize-LabVm.ps1')
    }
    parameters: []
    protectedParameters: []
    runAsUser: adminUsername
    runAsPassword: adminPassword
    timeoutInSeconds: 7200
    asyncExecution: false
    treatFailureAsDeploymentFailure: true
  }
}

output vmId string = virtualMachine.id
output vmNameOut string = virtualMachine.name
