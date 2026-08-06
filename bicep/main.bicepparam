using './main.bicep'

param envName = 'lab'
param location = 'westus2'
param resourceGroupName = 'lab-dev4'
param fabricRegion = 'westus2'
param fabricSkuName = 'F2'
param deployFabric = true
param deployFoundry = true
param fabricAdminMembers = [
  'johnbowen@mannu2050gmail578.onmicrosoft.com'
]
param vmAdminUsername = 'lab_user1'
param vmAdminPassword = '*****TODO*****'
param vmComputerName = 'cosmos-lab-t'
param applyVmSecurityType = false
param vmSize = 'Standard_D4s_v4'  // AMD v5, SCSI-compatible; swapped from D4s_v5 due to capacity restrictions in westus
param diskControllerType = 'SCSI'
param foundryDeploymentName = 'gpt5mini'
param foundryModelName = 'gpt-5-mini'
param foundryModelVersion = '2025-08-07'
param foundryEmbeddingDeploymentName = 'textembedding3small'
param foundryEmbeddingModelName = 'text-embedding-3-small'
param foundryEmbeddingModelVersion = '1'
param foundrySkuName = 'S0'
param aiFoundryProjectName = 'defaultproject'
param tags = {
  env: 'lab'
  project: 'cosmos-labs'
}
