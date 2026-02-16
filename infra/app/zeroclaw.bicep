@description('Location for the resource.')
param location string = resourceGroup().location

@description('Tags for the resource.')
param tags object = {}

@description('Name of the Container Apps managed environment.')
param containerAppsEnvironmentName string

@description('Connection string for PostgreSQL. Use secure parameter.')
param postgresqlConnectionString string

@description('Name for the App.')
param name string

@description('Name of the container.')
param containerName string = 'zeroclaw'

@description('Name of the container registry.')
param containerRegistryName string

@description('Port exposed by the ZeroClaw container.')
param containerPort int

@description('Minimum replica count for ZeroClaw containers.')
param containerMinReplicaCount int

@description('Maximum replica count for ZeroClaw containers.')
param containerMaxReplicaCount int

@description('Master key for ZeroClaw. Your master key for the proxy/gateway.')
@secure()
param zeroclaw_master_key string

@description('Salt key for ZeroClaw. (CAN NOT CHANGE ONCE SET)')
@secure()
param zeroclaw_salt_key string
@secure()
param openai_api_key string = ''

param zeroclawContainerAppExists bool

var abbrs = loadJsonContent('../abbreviations.json')
var identityName = '${abbrs.managedIdentityUserAssignedIdentities}${name}'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-04-01-preview' existing = {
  name: containerAppsEnvironmentName
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(subscription().id, resourceGroup().id, identity.id, 'acrPullRole')
  properties: {
    roleDefinitionId:  subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // ACR Pull role
    principalType: 'ServicePrincipal'
    principalId: identity.properties.principalId
  }
}

module fetchLatestContainerImage '../shared/fetch-container-image.bicep' = {
  name: '${name}-fetch-image'
  params: {
    exists: zeroclawContainerAppExists
    containerAppName: name
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: union(tags, {'azd-service-name':  'zeroclaw' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${identity.id}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: containerPort
        transport: 'auto'
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: identity.id
        }
      ]
      secrets: [
        {
          name: 'zeroclaw-master-key'
          value: zeroclaw_master_key
        }
        {
          name: 'zeroclaw-salt-key'
          value: zeroclaw_salt_key
        }
        {
          name: 'database-url'
          value: postgresqlConnectionString
        }
        {
          name: 'openai-api-key'
          value: openai_api_key
        }
      ]
    }
    template: {
      containers: [
        {
          name: containerName
          image: fetchLatestContainerImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          env: [
            {
              name: 'ZEROCLAW_MASTER_KEY'
              secretRef: 'zeroclaw-master-key'
            }
            {
              name: 'ZEROCLAW_SALT_KEY'
              secretRef: 'zeroclaw-salt-key'
            }
            {
              name: 'DATABASE_URL'
              secretRef: 'database-url'
            }
            {
              name: 'OPENAI_API_KEY'
              secretRef: 'openai-api-key'
            }
          ]
        }
      ]
      scale: {
        minReplicas: containerMinReplicaCount
        maxReplicas: containerMaxReplicaCount
      }
    }
  }
}

output containerAppName string = containerApp.name
output containerAppFQDN string = containerApp.properties.configuration.ingress.fqdn
