// shared.bicep - Workshop-wide shared infrastructure.
// Currently scopes to a single Fabric capacity used across all student
// workspaces in batch-mode provisioning. Subscription-scoped so it can
// create its own resource group.

targetScope = 'subscription'

@description('Resource group that holds workshop-wide shared resources.')
param resourceGroupName string

@description('Azure region for the shared resource group and Fabric capacity.')
param location string

@description('Fabric capacity name.')
param fabricCapacityName string

@description('Fabric capacity SKU (F2, F4, F8, F16, F32, F64).')
@allowed(['F2', 'F4', 'F8', 'F16', 'F32', 'F64'])
param fabricSkuName string

@description('Email addresses of Fabric capacity administrators.')
@minLength(1)
param fabricAdminMembers array

@description('Tags applied to all shared resources.')
param tags object

resource sharedResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module fabric './modules/fabric.bicep' = {
  scope: sharedResourceGroup
  params: {
    capacityName: fabricCapacityName
    location: location
    skuName: fabricSkuName
    adminMembers: fabricAdminMembers
    tags: tags
  }
}

output sharedResourceGroupName string = sharedResourceGroup.name
output fabricCapacityId string = fabric.outputs.capacityId
output fabricCapacityName string = fabric.outputs.capacityName
output fabricCapacitySku string = fabricSkuName
