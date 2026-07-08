// networking.bicep - VNet, subnet, NSG, public IP, NIC for the lab VM
targetScope = 'resourceGroup'

@description('Location for the networking resources')
param location string

@description('Environment name (used in resource naming)')
param envName string

@description('Unique suffix used for the public IP DNS label')
param uniqueSuffix string

var publicIpName = 'lab-vm-public-ip'
var nsgName = '${envName}-nsg'
var vnetName = '${envName}-vnet'
var subnetName = '${envName}-subnet'
var vmName = 'lab-vm-${envName}-01'
var nicName = '${vmName}Nic'
var dnsLabelPrefix = toLower('lab-${uniqueSuffix}')

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          priority: 300
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
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
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: nicName
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
            properties: {
              deleteOption: 'Detach'
            }
          }
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
        }
      }
    ]
  }
}

output nicId string = nic.id
output publicIpFqdn string = publicIp.properties.dnsSettings.fqdn
output publicIpAddress string = publicIp.properties.ipAddress
