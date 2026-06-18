// cosmosdb.provisioned.bicep - Cosmos DB account with Provisioned autoscale throughput
// Provides a provisioned autoscale Cosmos DB account for comparison with the serverless account
targetScope = 'resourceGroup'

param accountName string
param location string
param common object
param autoScaleSmallMaxRU int = 1000
// Make containers for partitioning demo large enough to allow physical partitioning
param autoScaleMaxRU int = 10000

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

// ====== Modeling DB ======
// Used for lab: Data Modeling
// Provisioned throughput is used here so monitor reports per-partition RU consumption

resource modelingDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: 'Modeling'
  parent: dbAccount
  properties: {
    resource: {
      id: 'Modeling'
    }
    // Mix of database and container level throughput
    options: {
      autoscaleSettings: {
        maxThroughput: autoScaleSmallMaxRU
      }
    }
  }
}

resource ordersHotContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'OrdersHot'
  parent: modelingDatabase
  properties: {
    resource: {
      id: 'OrdersHot'
      partitionKey: {
        paths: ['/customerId']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          { path: '/*' }
        ]
      }
    }
    // Container level throughput independent of the database setting
    options: {
      autoscaleSettings: {
        maxThroughput: autoScaleMaxRU
      }
    }
  }
}

resource ordersCompositeContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'OrdersComposite'
  parent: modelingDatabase
  properties: {
    resource: {
      id: 'OrdersComposite'
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          { path: '/*' }
        ]
      }
    }
    // Container level throughput independent of the database setting
    options: {
      autoscaleSettings: {
        maxThroughput: autoScaleMaxRU
      }
    }
  }
}

resource eventsTtlContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'EventsTtl'
  parent: modelingDatabase
  properties: {
    resource: {
      id: 'EventsTtl'
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
      }
      // 30 days
      defaultTtl: 2592000
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
