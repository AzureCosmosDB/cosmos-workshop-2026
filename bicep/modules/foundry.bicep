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

@description('Chat model deployment SKU (GlobalStandard is required for newer models that no longer offer regional Standard)')
param modelSkuName string = 'GlobalStandard'

@description('Embedding model deployment name')
param embeddingDeploymentName string

@description('Embedding model name (e.g. text-embedding-3-small)')
param embeddingModelName string

@description('Embedding model version')
param embeddingModelVersion string

@description('Optional Entra object ID to grant Cognitive Services data-plane access on this account')
param studentOwnerObjectId string = ''

var cognitiveServicesContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68')
var openAiContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442')

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
    name: modelSkuName
    capacity: 1
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

// Deploy serially after the chat model to avoid concurrent deployment limit
resource embeddingModelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: aiFoundryAccount
  name: embeddingDeploymentName
  sku: {
    name: 'Standard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: embeddingModelName
      version: embeddingModelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  dependsOn: [
    chatModelDeployment
  ]
}

// Grant the student data-plane access to chat completions / embeddings on this account.
// RG-level Owner does not include `Microsoft.CognitiveServices/accounts/OpenAI/.../action`.
resource studentCognitiveServicesContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(studentOwnerObjectId)) {
  scope: aiFoundryAccount
  name: guid(aiFoundryAccount.id, studentOwnerObjectId, cognitiveServicesContributorRoleId)
  properties: {
    roleDefinitionId: cognitiveServicesContributorRoleId
    principalId: studentOwnerObjectId
    principalType: 'User'
  }
}

resource studentOpenAiContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(studentOwnerObjectId)) {
  scope: aiFoundryAccount
  name: guid(aiFoundryAccount.id, studentOwnerObjectId, openAiContributorRoleId)
  properties: {
    roleDefinitionId: openAiContributorRoleId
    principalId: studentOwnerObjectId
    principalType: 'User'
  }
}

output endpoint string = aiFoundryAccount.properties.endpoint
output projectName string = aiFoundryProject.name
output deploymentName string = chatModelDeployment.name
output embeddingDeploymentName string = embeddingModelDeployment.name
#disable-next-line outputs-should-not-contain-secrets
output primaryKey string = aiFoundryAccount.listKeys().key1
