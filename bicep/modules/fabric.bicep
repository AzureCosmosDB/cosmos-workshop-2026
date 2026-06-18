// fabric.bicep - Microsoft Fabric capacity
targetScope = 'resourceGroup'

@description('Fabric capacity name')
param capacityName string

@description('Azure region for the Fabric capacity')
param location string

@description('Tags applied to the capacity')
param tags object

@description('Fabric capacity SKU (F2, F4, F8, F16, F32)')
param skuName string

@description('Email addresses of Fabric capacity administrators')
param adminMembers array

resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: capacityName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: adminMembers
    }
  }
}

output capacityId string = fabricCapacity.id
output capacityName string = fabricCapacity.name
