targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment (e.g., dev, test, prod)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Git SHA for versioning')
param gitSha string = ''

// Tags for all resources
var tags = {
  'azd-env-name': environmentName
  app: 'weather-api'
  version: gitSha != '' ? gitSha : 'local'
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// Core infrastructure (networking, storage, identity)
module core './modules/core.bicep' = {
  name: 'core-resources'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
  }
}

// Monitoring (Application Insights, Log Analytics, Grafana)
module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring-resources'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
  }
}

// Key Vault for secrets management
module keyVault './modules/keyvault.bicep' = {
  name: 'keyvault-resources'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    managedIdentityPrincipalId: core.outputs.managedIdentityPrincipalId
    principalId: principalId
  }
}

// Function App
module functionApp './modules/function-app.bicep' = {
  name: 'function-app'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    storageAccountName: core.outputs.storageAccountName
    vnetId: core.outputs.vnetId
    functionSubnetId: core.outputs.functionSubnetId
    privateEndpointSubnetId: core.outputs.privateEndpointSubnetId
    managedIdentityId: core.outputs.managedIdentityId
    managedIdentityPrincipalId: core.outputs.managedIdentityPrincipalId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    appInsightsId: monitoring.outputs.appInsightsId
    weatherApiKeySecretReference: keyVault.outputs.weatherApiKeySecretReference
    gitSha: gitSha
  }
}

// Prometheus Scraping Configuration (informational)
module prometheusConfig './modules/prometheus-scraping.bicep' = {
  name: 'prometheus-config'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    azureMonitorWorkspaceId: monitoring.outputs.azureMonitorWorkspaceId
    dataCollectionEndpointId: monitoring.outputs.dataCollectionEndpointId
    functionAppResourceId: functionApp.outputs.functionAppId
    functionAppUrl: functionApp.outputs.functionAppUrl
    functionAppName: functionApp.outputs.functionAppName
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_FUNCTION_APP_NAME string = functionApp.outputs.functionAppName
output AZURE_FUNCTION_APP_URL string = functionApp.outputs.functionAppUrl
output AZURE_STORAGE_ACCOUNT_NAME string = core.outputs.storageAccountName
output APP_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.appInsightsConnectionString
output AZURE_MONITOR_WORKSPACE_QUERY_ENDPOINT string = monitoring.outputs.azureMonitorWorkspaceQueryEndpoint
output GRAFANA_ENDPOINT string = monitoring.outputs.grafanaEndpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.keyVaultName
output AZURE_KEY_VAULT_URI string = keyVault.outputs.keyVaultUri
