@description('Primary location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('Resource tags')
param tags object

@description('Storage account name')
param storageAccountName string

@description('VNet ID')
param vnetId string

@description('Function subnet ID')
param functionSubnetId string

@description('Private endpoint subnet ID')
param privateEndpointSubnetId string

@description('Managed identity ID')
param managedIdentityId string

@description('Managed identity principal ID')
param managedIdentityPrincipalId string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Application Insights instrumentation key')
param appInsightsInstrumentationKey string

@description('Application Insights resource ID')
param appInsightsId string

@description('Weather API Key secret reference from Key Vault')
@secure()
param weatherApiKeySecretReference string

@description('Git SHA for versioning')
param gitSha string

// App Service Plan (Flex Consumption)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-${environmentName}'
  location: location
  tags: tags
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true // Linux
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  tags: union(tags, { gitSha: gitSha, 'azd-service-name': 'weather-api' })
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: 'https://${storageAccountName}.blob.${environment().suffixes.storage}/deploymentpackage'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: managedIdentityId
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '8.0'
      }
    }
    virtualNetworkSubnetId: functionSubnetId
    vnetRouteAllEnabled: true
    publicNetworkAccess: 'Enabled'
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: '${appInsightsConnectionString};Authentication=AAD'
        }
        {
          name: 'APPLICATIONINSIGHTS_AUTHENTICATION_STRING'
          value: 'Authorization=AAD'
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'BUILD_SOURCEVERSION'
          value: gitSha
        }
        {
          name: 'BUILD_DATE'
          value: '${gitSha}-deployed'
        }
        {
          name: 'AZURE_FUNCTIONS_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'WeatherApiKey'
          value: weatherApiKeySecretReference
        }
        {
          name: 'WeatherApiBaseUrl'
          value: 'https://api.weatherapi.com/v1'
        }
      ]
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

// Grant Monitoring Metrics Publisher role to Function App on Application Insights
resource appInsightsMetricsPublisher 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appInsightsConnectionString, managedIdentityId, 'metrics-publisher')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb') // Monitoring Metrics Publisher
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output functionAppName string = functionApp.name
output functionAppId string = functionApp.id
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionAppPrincipalId string = managedIdentityPrincipalId
