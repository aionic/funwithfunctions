@description('Primary location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('Resource tags')
param tags object

@description('Managed identity principal ID for Key Vault access')
param managedIdentityPrincipalId string

@description('Principal ID of the user/service principal for Key Vault access')
param principalId string = ''

// Key Vault name with location-based uniqueness
var keyVaultName = 'kv-${replace(environmentName, '-', '')}${uniqueString(resourceGroup().id, location)}'

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled' // Can be changed to 'Disabled' with private endpoint
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Role assignment for managed identity (Key Vault Secrets User)
resource keyVaultSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentityPrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Optional: Role assignment for deploying user (Key Vault Secrets Officer)
resource keyVaultSecretsOfficerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (principalId != '') {
  name: guid(keyVault.id, principalId, 'Key Vault Secrets Officer')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets Officer
    principalId: principalId
    principalType: 'User'
  }
}

// Weather API Key secret (placeholder - will be set via CLI or portal)
resource weatherApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'WeatherApiKey'
  properties: {
    value: 'placeholder-update-after-deployment'
    contentType: 'text/plain'
  }
}

output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output weatherApiKeySecretUri string = weatherApiKeySecret.properties.secretUri
output weatherApiKeySecretReference string = '@Microsoft.KeyVault(SecretUri=${weatherApiKeySecret.properties.secretUri})'
