targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('The Azure region for all resources.')
param location string

@description('Name of the resource group to create or use')
param resourceGroupName string 

@description('Port exposed by the ZeroClaw container.')
param containerPort int = 8080

@description('Minimum replica count for ZeroClaw containers.')
param containerMinReplicaCount int = 2

@description('Maximum replica count for ZeroClaw containers.')
param containerMaxReplicaCount int = 3

@description('Name of the PostgreSQL database.')
param databaseName string = 'zeroclawdb'

@description('Name of the PostgreSQL database admin user.')
param databaseAdminUser string = 'zeroclawuser'

@secure()
param databaseAdminPassword string = ''

param zeroclawContainerAppExists bool

@description('Use SQLite for app database. When true, external DB/Supabase and Azure PostgreSQL are disabled.')
param useSqlite bool = true

@description('SQLite database URL used when useSqlite is true.')
param sqliteDatabaseUrl string = 'sqlite:///data/zeroclaw.db'

@description('External database connection string (e.g. Supabase). If provided, the template will use this instead of provisioning Azure PostgreSQL.')
@secure()
param externalDatabaseConnectionString string = ''

@description('Master key for ZeroClaw. Your master key for the proxy/gateway.')
@secure()
param zeroclaw_master_key string

@description('Salt key for ZeroClaw. (CAN NOT CHANGE ONCE SET)')
@secure()
param zeroclaw_salt_key string
@secure()
param openai_api_key string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, resourceGroupName, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  'azd-template': 'https://github.com/Build5Nines/azd-zeroclaw'
}

var containerAppName = '${abbrs.appContainerApps}zeroclaw-${resourceToken}'
var postgresqlServerName = '${abbrs.dBforPostgreSQLServers}zeroclaw-${resourceToken}'
var postgresqlFqdn = '${postgresqlServerName}.postgres.database.azure.com'
var shouldUseAzurePostgres = !useSqlite && empty(externalDatabaseConnectionString)
var databaseConnectionString = useSqlite
  ? sqliteDatabaseUrl
  : (!empty(externalDatabaseConnectionString)
      ? externalDatabaseConnectionString
      : 'postgresql://${databaseAdminUser}:${databaseAdminPassword}@${postgresqlFqdn}/${databaseName}')

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module monitoring './shared/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}zeroclaw-${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}zeroclaw-${resourceToken}'
  }
  scope: rg
}

module containerRegistry './shared/container-registry.bicep' = {
  name: 'cotainer-registry'
  params: {
    location: location
    tags: tags
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
  }
  scope: rg
}

module appsEnv './shared/apps-env.bicep' = {
  name: 'apps-env'
  params: {
    name: '${abbrs.appManagedEnvironments}zeroclaw-${resourceToken}'
    location: location
    tags: tags 
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  }
  scope: rg
}

// Deploy PostgreSQL Server via module call.
module postgresql './shared/postgresql.bicep' = if (shouldUseAzurePostgres) {
  name: 'postgresql'
  params: {
    name: postgresqlServerName
    location: location
    tags: tags
    databaseAdminUser: databaseAdminUser
    databaseAdminPassword: databaseAdminPassword
  }
  scope: rg
}

// Deploy PostgreSQL Database via module call.
module postgresqlDatabase './shared/postgresql_database.bicep' = if (shouldUseAzurePostgres) {
  name: 'postgresqlDatabase'
  params: {
    serverName: postgresqlServerName
    databaseName: databaseName
  }
  scope: rg
}

// module keyvault './shared/keyvault.bicep' = {
//   name: 'keyvault'
//   params: {
//     name: '${abbrs.keyVaultVaults}zeroclaw-${resourceToken}'
//     location: location
//     tags: tags
//   }
//   scope: rg
// }

// Deploy ZeroClaw Container App via module call.
module zeroclaw './app/zeroclaw.bicep' = {
  name: 'zeroclaw'
  params: {
    name: containerAppName
    containerAppsEnvironmentName: appsEnv.outputs.name
    // keyvaultName: keyvault.outputs.name
    databaseConnectionString: databaseConnectionString
    zeroclaw_master_key: zeroclaw_master_key
    zeroclaw_salt_key: zeroclaw_salt_key
    openai_api_key: openai_api_key
    zeroclawContainerAppExists: zeroclawContainerAppExists

    containerRegistryName: containerRegistry.outputs.name
    containerPort: containerPort
    containerMinReplicaCount: containerMinReplicaCount
    containerMaxReplicaCount: containerMaxReplicaCount
  }
  scope: rg
}


output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer

//output ZEROCLAW_CONTAINER_APP_EXISTS bool = true
// output ZEROCLAW_CONTAINERAPP_FQDN string = zeroclaw.outputs.containerAppFQDN
// output POSTGRESQL_FQDN string = postgresql.outputs.fqdn
