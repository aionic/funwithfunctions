@description('Primary location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('Resource tags')
param tags object

@description('Azure Monitor Workspace resource ID')
param azureMonitorWorkspaceId string

@description('Data Collection Endpoint resource ID')
param dataCollectionEndpointId string

@description('Function App resource ID')
param functionAppResourceId string

@description('Function App URL')
param functionAppUrl string

@description('Function App name')
param functionAppName string

// Note: Azure Monitor Managed Service for Prometheus uses a different approach
// It requires Azure Kubernetes Service (AKS) or Azure Monitor agent on VMs
// For Azure Functions, we'll document the direct scraping approach instead

// For Functions, Grafana can scrape directly using Prometheus data source
// Configuration will be done via Grafana UI or API

// Output instructions for manual configuration
output grafanaPrometheusConfig object = {
  dataSourceType: 'prometheus'
  name: 'Function App Metrics (Direct)'
  url: '${functionAppUrl}/api/metrics'
  access: 'proxy'
  authType: 'functionKey'
  instructions: 'Add function key as custom HTTP header: x-functions-key'
}

output azureMonitorConfig object = {
  workspaceId: azureMonitorWorkspaceId
  instructions: 'Azure Monitor Workspace is configured to work with Grafana. For custom Prometheus scraping from Functions, use direct scraping approach.'
}
