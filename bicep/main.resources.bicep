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
param deployFabric bool = false

@description('Deploy Azure AI Foundry resources')
param deployFoundry bool = true

@description('Deploy Azure DocumentDB instead of Cosmos DB for NoSQL accounts, databases, and containers.')
param isDocDB bool = false

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

@description('Use the existing workshop VNet and subnet without updating them.')
param useExistingVnet bool = false

// ========== NAMING ======

var uniqueSuffix = toLower(uniqueString(resourceGroup().id))
var cosmosDbName = 'cosmos${envName}${uniqueSuffix}'
var cosmosDbProvisionedName = 'cosmos-provisioned-${envName}${uniqueSuffix}'
var documentDbName = 'docdb-${envName}-${uniqueSuffix}'
var aiFoundryName = 'aifoundry${envName}${uniqueSuffix}'
var fabricCapacityName = 'fabric${envName}${uniqueSuffix}'
var vmName = 'lab-vm-${envName}-01'
var ownerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')

// ========== NETWORKING ======

module networking './modules/networking.bicep' = {
  name: 'networking'
  params: {
    location: location
    envName: envName
    useExistingVnet: useExistingVnet
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

module cosmosServerless './modules/cosmosdb.bicep' = if (!isDocDB) {
  name: 'cosmos-serverless'
  params: {
    accountName: cosmosDbName
    location: location
    tags: tags
    studentOwnerObjectId: studentOwnerObjectId
  }
}

module cosmosProvisioned './modules/cosmosdb.provisioned.bicep' = if (!isDocDB) {
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

module documentDb './modules/documentdb.bicep' = if (isDocDB) {
  name: 'documentdb'
  params: {
    clusterName: documentDbName
    location: location
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    tags: tags
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

// ========== PRIVATE ENDPOINTS ======

module privateEndpoints './modules/private-endpoints.bicep' = {
  name: 'private-endpoints'
  params: {
    location: location
    envName: envName
    vnetId: networking.outputs.vnetId
    subnetId: networking.outputs.privateEndpointSubnetId
    deployCosmos: !isDocDB
    cosmosServerlessId: isDocDB ? '' : cosmosServerless!.outputs.accountId
    cosmosProvisionedId: isDocDB ? '' : cosmosProvisioned!.outputs.accountId
    deployFoundry: deployFoundry
    foundryAccountId: deployFoundry ? foundry!.outputs.accountId : ''
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

output cosmosDbEndpoint string = isDocDB ? '' : cosmosServerless!.outputs.endpoint
output provisionedCosmosEndpoint string = isDocDB ? '' : cosmosProvisioned!.outputs.accountEndpoint
output provisionedCosmosThroughputMode string = isDocDB ? '' : cosmosProvisioned!.outputs.throughputMode
output provisionedCosmosMaxRU int = isDocDB ? 0 : cosmosProvisioned!.outputs.maxAutoScaleRU
output documentDbConnectionString string = isDocDB ? documentDb!.outputs.connectionString : ''
output aiFoundryEndpoint string = deployFoundry ? foundry!.outputs.endpoint : ''
output aiFoundryProjectName string = deployFoundry ? foundry!.outputs.projectName : ''
output chatDeploymentName string = deployFoundry ? foundry!.outputs.deploymentName : ''
output embeddingDeploymentName string = deployFoundry ? foundry!.outputs.embeddingDeploymentName : ''
output vmPublicIp string = ''
output vmPublicIpAddress string = ''
output bastionName string = networking.outputs.bastionName
output bastionId string = networking.outputs.bastionId
output vmId string = vm.outputs.vmId
output vmAdminUsernameOut string = vmAdminUsername
output storageAccountBlobEndpoint string = ''
output fabricCapacityId string = deployFabric ? fabric!.outputs.capacityId : ''
output cosmosAccountName string = isDocDB ? '' : cosmosDbName
output cosmosProvisionedAccountName string = isDocDB ? '' : cosmosDbProvisionedName
output documentDbClusterName string = isDocDB ? documentDb!.outputs.clusterName : ''
output foundryAccountName string = deployFoundry ? aiFoundryName : ''
output storageAccountName string = ''
output vmName string = vmName
