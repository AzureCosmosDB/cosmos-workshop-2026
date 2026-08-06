// documentdb.bicep - Azure DocumentDB cluster for workshop environments

@description('DocumentDB cluster name.')
param clusterName string

@description('Location for the DocumentDB cluster.')
param location string

@description('Administrator username for the DocumentDB cluster.')
param adminUsername string

@secure()
@description('Administrator password for the DocumentDB cluster.')
@minLength(8)
@maxLength(128)
param adminPassword string

@description('Tags for the DocumentDB cluster.')
param tags object

resource cluster 'Microsoft.DocumentDB/mongoClusters@2025-09-01' = {
  name: clusterName
  location: location
  tags: tags
  properties: {
    administrator: {
      userName: adminUsername
      password: adminPassword
    }
    serverVersion: '8.0'
    sharding: {
      shardCount: 1
    }
    storage: {
      sizeGb: 32
    }
    highAvailability: {
      targetMode: 'Disabled'
    }
    compute: {
      tier: 'M10'
    }
  }
}

resource allowAzureServices 'Microsoft.DocumentDB/mongoClusters/firewallRules@2025-09-01' = {
  parent: cluster
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('Name of the DocumentDB cluster.')
output clusterName string = cluster.name

@description('Connection string for the DocumentDB cluster with a password placeholder.')
output connectionString string = cluster.properties.connectionString