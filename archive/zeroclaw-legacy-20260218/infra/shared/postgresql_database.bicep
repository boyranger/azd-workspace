param serverName string
param databaseName string

resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-11-01-preview' existing = {
  name: serverName
}

resource postgresqlDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-11-01-preview' = {
  name: databaseName
  parent: postgresqlServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

output name string = postgresqlDatabase.name
