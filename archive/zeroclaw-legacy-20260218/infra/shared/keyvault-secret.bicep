@description('Name of the Key Vault.')
param keyvaultName string

@description('Name of the secret.')
param secretName string

@description('The secret value.')
@secure()
param secretValue string

resource keyvault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyvaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyvault
  name: secretName
  properties: {
    value: secretValue
  }
}

output keyvaultName string = keyvaultName
output secretName string = secretName
