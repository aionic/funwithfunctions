@description('Primary location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('Resource tags')
param tags object

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${environmentName}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${environmentName}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Azure Monitor Workspace (for Prometheus)
resource azureMonitorWorkspace 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: 'mon-${environmentName}'
  location: location
  tags: tags
}

// Data Collection Endpoint for Prometheus metrics
resource dataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2022-06-01' = {
  name: 'dce-${environmentName}'
  location: location
  tags: tags
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

// Azure Managed Grafana
resource grafana 'Microsoft.Dashboard/grafana@2023-09-01' = {
  name: 'grafana-${environmentName}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    grafanaIntegrations: {
      azureMonitorWorkspaceIntegrations: [
        {
          azureMonitorWorkspaceResourceId: azureMonitorWorkspace.id
        }
      ]
    }
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

// Grant Grafana Monitoring Reader role on the resource group
resource grafanaMonitoringReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, grafana.id, 'monitoring-reader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05') // Monitoring Reader
    principalId: grafana.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsId string = appInsights.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output azureMonitorWorkspaceId string = azureMonitorWorkspace.id
output azureMonitorWorkspaceQueryEndpoint string = azureMonitorWorkspace.properties.metrics.prometheusQueryEndpoint
output dataCollectionEndpointId string = dataCollectionEndpoint.id
output grafanaId string = grafana.id
output grafanaEndpoint string = grafana.properties.endpoint
