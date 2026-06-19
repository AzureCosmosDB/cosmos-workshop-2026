using './main.bicep'

param envName = 'lab'
param location = 'westus'
param resourceGroupName = 'lab-dev4'
param fabricRegion = 'westus'
param fabricSkuName = 'F2'
param deployFabric = true
param deployFoundry = true
param fabricAdminMembers = [
  'johnbowen@mannu2050gmail578.onmicrosoft.com'
]
param vmAdminUsername = 'lab_user1'
param vmAdminPassword = '*****TODO*****'
param vmComputerName = 'bc-cosmos-lab-t'
param applyVmSecurityType = false
param vmSize = 'Standard_D2s_v3'
param foundryDeploymentName = 'gpt41'
param foundryModelName = 'gpt-4.1-mini'
param foundryModelVersion = '2025-04-14'
param foundryEmbeddingDeploymentName = 'textembedding3small'
param foundryEmbeddingModelName = 'text-embedding-3-small'
param foundryEmbeddingModelVersion = '1'
param foundrySkuName = 'S0'
param aiFoundryProjectName = 'defaultproject'
param tags = {
  env: 'lab'
  project: 'cosmos-labs'
}
