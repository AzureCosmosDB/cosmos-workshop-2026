// cosmosdb.bicep - Serverless Cosmos DB account with Conversations and WorkshopData databases
targetScope = 'resourceGroup'

@description('Cosmos DB account name')
param accountName string

@description('Location for the Cosmos DB account')
param location string

@description('Tags applied to the account')
param tags object

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: 'Enabled'
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
    capabilities: [
      { name: 'EnableServerless' }
      { name: 'EnableNoSQLVectorSearch' }
      { name: 'EnableFullTextSearch' }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        failoverPriority: 0
        isZoneRedundant: false
        locationName: location
      }
    ]
  }
}

// ========== CONVERSATIONS DATABASE ==========

resource conversationsDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: 'Conversations'
  parent: cosmosAccount
  properties: {
    resource: {
      id: 'Conversations'
    }
  }
}

resource sessionsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'Sessions'
  parent: conversationsDatabase
  properties: {
    resource: {
      id: 'Sessions'
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
  }
}

resource messagesContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'Messages'
  parent: conversationsDatabase
  properties: {
    resource: {
      id: 'Messages'
      partitionKey: {
        paths: ['/sessionId']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          { path: '/*' }
        ]
        excludedPaths: [
          { path: '/_etag/?' }
        ]
      }
    }
  }
}

// ========== WORKSHOP DATA DATABASE ==========

resource workshopDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: 'WorkshopData'
  parent: cosmosAccount
  properties: {
    resource: {
      id: 'WorkshopData'
    }
  }
}

resource catalogContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'Catalog'
  parent: workshopDatabase
  properties: {
    resource: {
      id: 'Catalog'
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
  }
}

var vectorEmbeddingPolicy = {
  vectorEmbeddings: [
    {
      path: '/embedding'
      dataType: 'float32'
      distanceFunction: 'cosine'
      dimensions: 1536
    }
  ]
}

var indexingPolicyWithVector = {
  indexingMode: 'consistent'
  automatic: true
  includedPaths: [
    { path: '/*' }
  ]
  excludedPaths: [
    { path: '/_etag/?' }
    { path: '/embedding/*' }
  ]
  vectorIndexes: [
    {
      path: '/embedding'
      type: 'DiskANN'
    }
  ]
  fullTextIndexes: [
    {
      path: '/text'
    }
    {
      path: '/title'
    }
  ]
}

var fullTextPolicy = {
  defaultLanguage: 'en-US'
  fullTextPaths: [
    {
      path: '/text'
      language: 'en-US'
    }
    {
      path: '/title'
      language: 'en-US'
    }
  ]
}

resource docsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'Docs'
  parent: workshopDatabase
  properties: {
    resource: {
      id: 'Docs'
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
      }
      vectorEmbeddingPolicy: vectorEmbeddingPolicy
      #disable-next-line BCP037
      fullTextPolicy: fullTextPolicy
      #disable-next-line BCP037
      indexingPolicy: indexingPolicyWithVector
    }
  }
}

// ========== LAB 1D2: INDEXING POLICY ==========

resource itemsDefaultIndexContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'ItemsDefaultIndex'
  parent: workshopDatabase
  properties: {
    resource: {
      id: 'ItemsDefaultIndex'
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          { path: '/*' }
        ]
      }
    }
  }
}

resource itemsCustomIndexContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'ItemsCustomIndex'
  parent: workshopDatabase
  properties: {
    resource: {
      id: 'ItemsCustomIndex'
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          { path: '/*' }
        ]
        excludedPaths: [
          { path: '/largeBlob/?' }
          { path: '/metadata/*' }
        ]
      }
    }
  }
}

output endpoint string = cosmosAccount.properties.documentEndpoint
#disable-next-line outputs-should-not-contain-secrets
output primaryKey string = cosmosAccount.listKeys().primaryMasterKey
