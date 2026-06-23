using './shared.bicep'

param resourceGroupName = 'lab-shared-fabric'
param location = 'westus'
param fabricCapacityName = 'fabricworkshopshared'
param fabricSkuName = 'F2'
param fabricAdminMembers = [
  'johnbowen@mannu2050gmail578.onmicrosoft.com'
]
param tags = {
  project: 'cosmos-labs'
  scope: 'shared'
}
