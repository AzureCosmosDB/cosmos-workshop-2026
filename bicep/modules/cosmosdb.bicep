// cosmosdb.bicep - Serverless Cosmos DB account with Conversations and WorkshopData databases
targetScope = 'resourceGroup'

@description('Cosmos DB account name')
param accountName string

@description('Location for the Cosmos DB account')
param location string

@description('Tags applied to the account')
param tags object

@description('Optional Entra object ID to grant Cosmos DB data-plane (SQL) access on this account')
param studentOwnerObjectId string = ''

// Cosmos DB's built-in "Cosmos DB Built-in Data Contributor" role, scoped per-account (not a Microsoft.Authorization role).
var dataContributorRoleId = '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
    capabilities: [
      { name: 'EnableServerless' }
      { name: 'EnableNoSQLVectorSearch' }
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

// RG-level Owner does not include Cosmos DB SQL data-plane actions; grant them explicitly.
resource studentDataContributorAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = if (!empty(studentOwnerObjectId)) {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, studentOwnerObjectId, dataContributorRoleId)
  properties: {
    roleDefinitionId: dataContributorRoleId
    principalId: studentOwnerObjectId
    scope: cosmosAccount.id
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

// ========== LAB 1E: DATA MODELING — REFERENCE (NORMALIZED) DATABASE ==========

resource modelingReferenceDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: 'ModelingReference'
  parent: cosmosAccount
  properties: {
    resource: {
      id: 'ModelingReference'
    }
  }
}

var modelingReferenceContainerNames = [
  'Customers'
  'Addresses'
  'ProductCategories'
  'Products'
  'Orders'
  'OrderItems'
]

resource modelingReferenceContainers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = [for name in modelingReferenceContainerNames: {
  name: name
  parent: modelingReferenceDatabase
  properties: {
    resource: {
      id: name
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
}]

// ========== LAB 1E: DATA MODELING — EMBED (DENORMALIZED) DATABASE ==========

resource modelingEmbedDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: 'ModelingEmbed'
  parent: cosmosAccount
  properties: {
    resource: {
      id: 'ModelingEmbed'
    }
  }
}

var modelingEmbedContainerNames = [
  'Customers'
  'Products'
  'Orders'
]

resource modelingEmbedContainers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = [for name in modelingEmbedContainerNames: {
  name: name
  parent: modelingEmbedDatabase
  properties: {
    resource: {
      id: name
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
}]

output endpoint string = cosmosAccount.properties.documentEndpoint
output accountId string = cosmosAccount.id
