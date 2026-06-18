// foundry.bicep - Azure AI Foundry account, default project, and chat model deployment
targetScope = 'resourceGroup'

@description('AI Foundry account name (also used as custom subdomain)')
param accountName string

@description('Location for the AI Foundry resources')
param location string

@description('Tags applied to the account')
param tags object

@description('AI Foundry account SKU (e.g. S0)')
param skuName string

@description('Name of the default AI Foundry project')
param projectName string

@description('Chat model deployment name')
param deploymentName string

@description('Chat model name')
param modelName string

@description('Chat model version')
param modelVersion string

resource aiFoundryAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  kind: 'AIServices'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: skuName
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

resource aiFoundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: aiFoundryAccount
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

resource chatModelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: aiFoundryAccount
  name: deploymentName
  sku: {
    name: 'GlobalStandard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'Microsoft'
      name: modelName
      version: modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

output endpoint string = aiFoundryAccount.properties.endpoint
output projectName string = aiFoundryProject.name
output deploymentName string = chatModelDeployment.name
#disable-next-line outputs-should-not-contain-secrets
output primaryKey string = aiFoundryAccount.listKeys().key1
