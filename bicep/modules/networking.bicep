// networking.bicep - VNet, subnets, NIC, and Bastion for the lab VM
targetScope = 'resourceGroup'

@description('Location for the networking resources')
param location string

@description('Environment name (used in resource naming)')
param envName string

@description('Use the existing workshop VNet and subnet without updating them.')
param useExistingVnet bool = false

var bastionPublicIpName = '${envName}-bastion-public-ip'
var bastionName = '${envName}-bastion'
var vnetName = '${envName}-vnet'
var subnetName = '${envName}-subnet'
var bastionSubnetName = 'AzureBastionSubnet'
var privateEndpointSubnetName = '${envName}-private-endpoints'
var vmName = 'lab-vm-${envName}-01'
var nicName = '${vmName}Nic'

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: bastionPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = if (!useExistingVnet) {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: '10.0.1.0/26'
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (useExistingVnet) {
  name: vnetName
}

@onlyIfNotExists()
resource existingBastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (useExistingVnet) {
  parent: existingVnet
  name: bastionSubnetName
  properties: {
    addressPrefix: '10.0.1.0/26'
  }
}

@onlyIfNotExists()
resource existingPrivateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (useExistingVnet) {
  parent: existingVnet
  name: privateEndpointSubnetName
  properties: {
    addressPrefix: '10.0.2.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    enableShareableLink: true
    ipConfigurations: [
      {
        name: 'bastion-ip-configuration'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPublicIp.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, bastionSubnetName)
          }
        }
      }
    ]
  }
  dependsOn: useExistingVnet ? [existingBastionSubnet] : [vnet]
}

resource nic 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
  }
  dependsOn: useExistingVnet ? [] : [vnet]
}

output nicId string = nic.id
output vnetId string = resourceId('Microsoft.Network/virtualNetworks', vnetName)
output privateEndpointSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, privateEndpointSubnetName)
output bastionName string = bastion.name
output bastionId string = bastion.id
