using './main.bicep'

param envName = 'lab'
param location = 'westus2'
param resourceGroupName = 'lab-dev1'
param fabricRegion = 'westus2'
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
param vmSize = 'Standard_D2as_v5'
param foundryDeploymentName = 'phi4mini'
param foundryModelName = 'Phi-4-mini-reasoning'
param foundryModelVersion = '1'
param foundrySkuName = 'S0'
param aiFoundryProjectName = 'defaultproject'
param tags = {
  env: 'lab'
  project: 'cosmos-labs'
}
