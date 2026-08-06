// cosmosdb.provisioned.bicep - Cosmos DB account with Provisioned autoscale throughput
// Provides a provisioned autoscale Cosmos DB account for comparison with the serverless account
targetScope = 'resourceGroup'

param accountName string
param location string
param common object
param autoScaleMaxRU int = 4000

@description('Optional Entra object ID to grant Cosmos DB data-plane (SQL) access on this account')
param studentOwnerObjectId string = ''

// Cosmos DB's built-in "Cosmos DB Built-in Data Contributor" role, scoped per-account (not a Microsoft.Authorization role).
var dataContributorRoleId = '${dbAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'

resource dbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: common.tags
  properties: {
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
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

// RG-level Owner does not include Cosmos DB SQL data-plane actions; grant them explicitly.
resource studentDataContributorAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = if (!empty(studentOwnerObjectId)) {
  parent: dbAccount
  name: guid(dbAccount.id, studentOwnerObjectId, dataContributorRoleId)
  properties: {
    roleDefinitionId: dataContributorRoleId
    principalId: studentOwnerObjectId
    scope: dbAccount.id
  }
}

// ====== Modeling DB ======
// Used for lab: Data Modeling
// Provisioned throughput is used here to compare per-partition RU consumption

resource modelingDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: 'Modeling'
  parent: dbAccount
  properties: {
    resource: {
      id: 'Modeling'
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
        paths: ['/orderDate']
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

output accountName string = dbAccount.name
output accountEndpoint string = dbAccount.properties.documentEndpoint
output throughputMode string = 'Provisioned with autoscale'
output maxAutoScaleRU int = autoScaleMaxRU
