targetScope = 'resourceGroup'

@description('Location for private endpoints.')
param location string

@description('Environment name used in resource names.')
param envName string

@description('Resource ID of the workshop virtual network.')
param vnetId string

@description('Resource ID of the private endpoint subnet.')
param subnetId string

@description('Create private endpoints for the two Cosmos DB accounts.')
param deployCosmos bool

@description('Resource ID of the serverless Cosmos DB account.')
param cosmosServerlessId string

@description('Resource ID of the provisioned Cosmos DB account.')
param cosmosProvisionedId string

@description('Create a private endpoint for Azure AI Foundry.')
param deployFoundry bool

@description('Resource ID of the Azure AI Foundry account.')
param foundryAccountId string

resource cosmosDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployCosmos) {
  name: 'privatelink.documents.azure.com'
  location: 'global'
}

resource cognitiveServicesDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployFoundry) {
  name: 'privatelink.cognitiveservices.azure.com'
  location: 'global'
}

resource openAiDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployFoundry) {
  name: 'privatelink.openai.azure.com'
  location: 'global'
}

resource aiServicesDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployFoundry) {
  name: 'privatelink.services.ai.azure.com'
  location: 'global'
}

resource cosmosDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (deployCosmos) {
  parent: cosmosDnsZone
  name: '${envName}-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnetId }
  }
}

resource cognitiveServicesDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (deployFoundry) {
  parent: cognitiveServicesDnsZone
  name: '${envName}-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnetId }
  }
}

resource openAiDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (deployFoundry) {
  parent: openAiDnsZone
  name: '${envName}-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnetId }
  }
}

resource aiServicesDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (deployFoundry) {
  parent: aiServicesDnsZone
  name: '${envName}-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnetId }
  }
}

resource cosmosServerlessEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (deployCosmos) {
  name: '${envName}-cosmos-serverless-pe'
  location: location
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'cosmos-serverless'
        properties: {
          privateLinkServiceId: cosmosServerlessId
          groupIds: ['Sql']
        }
      }
    ]
  }
}

resource cosmosServerlessDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (deployCosmos) {
  parent: cosmosServerlessEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cosmos-sql'
        properties: { privateDnsZoneId: cosmosDnsZone.id }
      }
    ]
  }
}

resource cosmosProvisionedEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (deployCosmos) {
  name: '${envName}-cosmos-provisioned-pe'
  location: location
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'cosmos-provisioned'
        properties: {
          privateLinkServiceId: cosmosProvisionedId
          groupIds: ['Sql']
        }
      }
    ]
  }
}

resource cosmosProvisionedDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (deployCosmos) {
  parent: cosmosProvisionedEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cosmos-sql'
        properties: { privateDnsZoneId: cosmosDnsZone.id }
      }
    ]
  }
}

resource foundryEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (deployFoundry) {
  name: '${envName}-foundry-pe'
  location: location
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'foundry'
        properties: {
          privateLinkServiceId: foundryAccountId
          groupIds: ['account']
        }
      }
    ]
  }
}

resource foundryDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (deployFoundry) {
  parent: foundryEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cognitive-services'
        properties: { privateDnsZoneId: cognitiveServicesDnsZone.id }
      }
      {
        name: 'openai'
        properties: { privateDnsZoneId: openAiDnsZone.id }
      }
      {
        name: 'ai-services'
        properties: { privateDnsZoneId: aiServicesDnsZone.id }
      }
    ]
  }
}
