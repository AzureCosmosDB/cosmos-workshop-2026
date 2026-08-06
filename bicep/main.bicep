// main.bicep - Lab Infrastructure
// Creates the resource group if needed, then deploys the lab resources into it.

targetScope = 'subscription'

// ========== PARAMETERS ======

@description('Environment name (used in resource naming)')
@minLength(1)
@maxLength(4)
param envName string

@description('Location for all resources')
param location string

@description('Name of the resource group to create or deploy into')
param resourceGroupName string

@description('Azure region for the Fabric capacity')
param fabricRegion string

@description('Fabric capacity SKU (F2, F4, F8, F16, F32)')
@allowed(['F2', 'F4', 'F8', 'F16', 'F32'])
param fabricSkuName string

@description('Deploy Microsoft Fabric capacity resources')
param deployFabric bool = true

@description('Deploy Azure AI Foundry resources')
param deployFoundry bool = true

@description('Email addresses of Fabric capacity administrators')
@minLength(1)
param fabricAdminMembers array

@description('VM admin username (cannot be admin, administrator, root)')
param vmAdminUsername string

@description('Password for the lab VM')
@minLength(12)
@secure()
param vmAdminPassword string

@description('VM size (D4s_v3 or compatible)')
param vmSize string

@description('Disk controller type - use NVMe for v5/v6 series sizes that support it')
param diskControllerType string = 'SCSI'

@description('Computer name for the lab VM')
param vmComputerName string

@description('Apply VM securityType during deployment. Use true for initial create, false for reruns when VM already exists.')
param applyVmSecurityType bool = true

@description('Azure AI Foundry (single-project) chat model deployment name')
param foundryDeploymentName string

@description('Azure AI Foundry chat model name')
param foundryModelName string

@description('Azure AI Foundry chat model version')
param foundryModelVersion string

@description('Azure AI Foundry embedding model deployment name')
param foundryEmbeddingDeploymentName string

@description('Azure AI Foundry embedding model name (e.g. text-embedding-3-small)')
param foundryEmbeddingModelName string

@description('Azure AI Foundry embedding model version')
param foundryEmbeddingModelVersion string

@description('Azure AI Foundry embedding model deployment SKU (GlobalStandard has the widest regional availability)')
param foundryEmbeddingSkuName string = 'GlobalStandard'

@description('Azure AI Foundry account SKU (S0 = standard)')
param foundrySkuName string

@description('Name of the default AI Foundry project created in the account')
param aiFoundryProjectName string

@description('Tags for all resources')
param tags object

@description('Optional Entra object ID for the student who should be granted Owner on this resource group')
param studentOwnerObjectId string = ''

// ========== HELPERS ======

resource labResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module lab './main.resources.bicep' = {
  scope: labResourceGroup
  params: {
    envName: envName
    location: location
    fabricRegion: fabricRegion
    fabricSkuName: fabricSkuName
    deployFabric: deployFabric
    deployFoundry: deployFoundry
    fabricAdminMembers: fabricAdminMembers
    vmAdminUsername: vmAdminUsername
    vmAdminPassword: vmAdminPassword
    vmSize: vmSize
    diskControllerType: diskControllerType
    vmComputerName: vmComputerName
    applyVmSecurityType: applyVmSecurityType
    foundryDeploymentName: foundryDeploymentName
    foundryModelName: foundryModelName
    foundryModelVersion: foundryModelVersion
    foundryEmbeddingDeploymentName: foundryEmbeddingDeploymentName
    foundryEmbeddingModelName: foundryEmbeddingModelName
    foundryEmbeddingModelVersion: foundryEmbeddingModelVersion
    foundryEmbeddingSkuName: foundryEmbeddingSkuName
    foundrySkuName: foundrySkuName
    aiFoundryProjectName: aiFoundryProjectName
    tags: tags
    studentOwnerObjectId: studentOwnerObjectId
  }
}

// ========== OUTPUTS ======

output cosmosDbEndpoint string = lab.outputs.cosmosDbEndpoint
output provisionedCosmosEndpoint string = lab.outputs.provisionedCosmosEndpoint
output provisionedCosmosThroughputMode string = lab.outputs.provisionedCosmosThroughputMode
output provisionedCosmosMaxRU int = lab.outputs.provisionedCosmosMaxRU
output aiFoundryEndpoint string = lab.outputs.aiFoundryEndpoint
output aiFoundryProjectName string = lab.outputs.aiFoundryProjectName
output chatDeploymentName string = lab.outputs.chatDeploymentName
output embeddingDeploymentName string = lab.outputs.embeddingDeploymentName
output vmPublicIp string = lab.outputs.vmPublicIp
output vmPublicIpAddress string = lab.outputs.vmPublicIpAddress
output vmAdminUsernameOut string = lab.outputs.vmAdminUsernameOut
output storageAccountBlobEndpoint string = lab.outputs.storageAccountBlobEndpoint
output fabricCapacityId string = lab.outputs.fabricCapacityId
output cosmosAccountName string = lab.outputs.cosmosAccountName
output cosmosProvisionedAccountName string = lab.outputs.cosmosProvisionedAccountName
output foundryAccountName string = lab.outputs.foundryAccountName
output storageAccountName string = lab.outputs.storageAccountName
output vmName string = lab.outputs.vmName
output resourceGroupNameOut string = resourceGroupName
