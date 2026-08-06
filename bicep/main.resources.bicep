// main.resources.bicep - Lab Infrastructure (resource-group scope)
// Orchestrates modules for networking, Cosmos DB (serverless + provisioned),
// Azure AI Foundry, Fabric capacity, and the lab VM.

targetScope = 'resourceGroup'

// ========== PARAMETERS ======

@description('Environment name (used in resource naming)')
@minLength(1)
@maxLength(4)
param envName string

@description('Location for all resources')
param location string

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

// ========== NAMING ======

var uniqueSuffix = toLower(uniqueString(resourceGroup().id))
var cosmosDbName = 'cosmos${envName}${uniqueSuffix}'
var cosmosDbProvisionedName = 'cosmos-provisioned-${envName}${uniqueSuffix}'
var aiFoundryName = 'aifoundry${envName}${uniqueSuffix}'
var storageName = 'st${envName}${uniqueSuffix}'
var fabricCapacityName = 'fabric${envName}${uniqueSuffix}'
var vmName = 'lab-vm-${envName}-01'
var ownerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')

// ========== NETWORKING ======

module networking './modules/networking.bicep' = {
  name: 'networking'
  params: {
    location: location
    envName: envName
    uniqueSuffix: uniqueSuffix
  }
}

// ========== OPTIONAL STUDENT OWNER ASSIGNMENT ======

// Grant the student Owner access only when the deployment is being used for per-student environments.
resource studentOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(studentOwnerObjectId)) {
  name: guid(resourceGroup().id, studentOwnerObjectId, ownerRoleDefinitionId)
  properties: {
    roleDefinitionId: ownerRoleDefinitionId
    principalId: studentOwnerObjectId
    principalType: 'User'
  }
}

// ========== COSMOS DB ======

module cosmosServerless './modules/cosmosdb.bicep' = {
  name: 'cosmos-serverless'
  params: {
    accountName: cosmosDbName
    location: location
    tags: tags
    studentOwnerObjectId: studentOwnerObjectId
  }
}

module cosmosProvisioned './modules/cosmosdb.provisioned.bicep' = {
  name: 'provisioned-cosmos'
  params: {
    accountName: cosmosDbProvisionedName
    location: location
    common: {
      envName: envName
      tags: tags
    }
    autoScaleMaxRU: 1000
    studentOwnerObjectId: studentOwnerObjectId
  }
}

// ========== AZURE STORAGE ======

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// RG-level Owner does not include Storage blob data-plane actions; grant them explicitly.
var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource studentStorageBlobDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(studentOwnerObjectId)) {
  scope: storageAccount
  name: guid(storageAccount.id, studentOwnerObjectId, storageBlobDataContributorRoleId)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: studentOwnerObjectId
    principalType: 'User'
  }
}

// ========== AZURE AI FOUNDRY ======

module foundry './modules/foundry.bicep' = if (deployFoundry) {
  name: 'foundry'
  params: {
    accountName: aiFoundryName
    location: location
    tags: tags
    skuName: foundrySkuName
    projectName: aiFoundryProjectName
    deploymentName: foundryDeploymentName
    modelName: foundryModelName
    modelVersion: foundryModelVersion
    embeddingDeploymentName: foundryEmbeddingDeploymentName
    embeddingModelName: foundryEmbeddingModelName
    embeddingModelVersion: foundryEmbeddingModelVersion
    embeddingSkuName: foundryEmbeddingSkuName
    studentOwnerObjectId: studentOwnerObjectId
  }
}

// ========== FABRIC CAPACITY ======

module fabric './modules/fabric.bicep' = if (deployFabric) {
  name: 'fabric'
  params: {
    capacityName: fabricCapacityName
    location: fabricRegion
    tags: tags
    skuName: fabricSkuName
    adminMembers: fabricAdminMembers
  }
}

// ========== LAB VM ======

module vm './modules/vm.bicep' = {
  name: 'vm-${vmName}'
  params: {
    location: location
    vmName: vmName
    vmComputerName: vmComputerName
    vmSize: vmSize
    diskControllerType: diskControllerType
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    nicId: networking.outputs.nicId
    tags: tags
    applyVmSecurityType: applyVmSecurityType
  }
}

// ========== OUTPUTS ======

output cosmosDbEndpoint string = cosmosServerless.outputs.endpoint
output provisionedCosmosEndpoint string = cosmosProvisioned.outputs.accountEndpoint
output provisionedCosmosThroughputMode string = cosmosProvisioned.outputs.throughputMode
output provisionedCosmosMaxRU int = cosmosProvisioned.outputs.maxAutoScaleRU
output aiFoundryEndpoint string = deployFoundry ? foundry!.outputs.endpoint : ''
output aiFoundryProjectName string = deployFoundry ? foundry!.outputs.projectName : ''
output chatDeploymentName string = deployFoundry ? foundry!.outputs.deploymentName : ''
output embeddingDeploymentName string = deployFoundry ? foundry!.outputs.embeddingDeploymentName : ''
output vmPublicIp string = networking.outputs.publicIpFqdn
output vmPublicIpAddress string = networking.outputs.publicIpAddress
output vmAdminUsernameOut string = vmAdminUsername
output storageAccountBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output fabricCapacityId string = deployFabric ? fabric!.outputs.capacityId : ''
output cosmosAccountName string = cosmosDbName
output cosmosProvisionedAccountName string = cosmosDbProvisionedName
output foundryAccountName string = deployFoundry ? aiFoundryName : ''
output storageAccountName string = storageName
output vmName string = vmName
