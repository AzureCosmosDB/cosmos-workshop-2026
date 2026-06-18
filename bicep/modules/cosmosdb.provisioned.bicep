// cosmosdb.provisioned.bicep - Cosmos DB account with Provisioned autoscale throughput
// Provides a provisioned autoscale Cosmos DB account for comparison with the serverless account
targetScope = 'resourceGroup'

param accountName string
param location string
param common object
param autoScaleMaxRU int = 1000

resource dbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: common.tags
  properties: {
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: 'Enabled'
    capabilities: [
      { name: 'EnableNoSQLVectorSearch' }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        failoverPriority: 0
        isZoneRedundant: false
        locationName: location
      }
    ]
    enableFreeTier: false
  }
}

// ====== Accounts DB ======

resource accountsDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: 'Accounts'
  parent: dbAccount
  properties: {
    resource: {
      id: 'Accounts'
    }
  }
}

resource usersContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'Users'
  parent: accountsDatabase
  properties: {
    resource: {
      id: 'Users'
      partitionKey: {
        paths: ['/userId']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          { path: '/*' }
        ]
      }
    }
    options: {
      autoscaleSettings: {
        maxThroughput: autoScaleMaxRU
      }
    }
  }
}

// ====== Sales DB ======

resource salesDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: 'Sales'
  parent: dbAccount
  properties: {
    resource: {
      id: 'Sales'
    }
    options: {
      autoscaleSettings: {
        maxThroughput: autoScaleMaxRU
      }
    }
  }
}

resource inventoryContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'Inventory'
  parent: salesDatabase
  properties: {
    resource: {
      id: 'Inventory'
      partitionKey: {
        paths: ['/category']
        kind: 'Hash'
      }
      defaultTtl: -1
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          { path: '/*' }
        ]
      }
    }
  }
}

resource ordersContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'Orders'
  parent: salesDatabase
  properties: {
    resource: {
      id: 'Orders'
      partitionKey: {
        paths: ['/orderId']
        kind: 'Hash'
      }
      defaultTtl: -1
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          { path: '/*' }
        ]
      }
    }
  }
}

output accountName string = dbAccount.name
output accountEndpoint string = dbAccount.properties.documentEndpoint
#disable-next-line outputs-should-not-contain-secrets
output primaryKey string = dbAccount.listKeys().primaryMasterKey
output throughputMode string = 'Provisioned with autoscale'
output maxAutoScaleRU int = autoScaleMaxRU
