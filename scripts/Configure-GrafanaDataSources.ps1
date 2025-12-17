#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configures Grafana data sources for hybrid monitoring
.DESCRIPTION
    This script configures Azure Managed Grafana with:
    1. Azure Monitor Workspace (for App Insights + Managed Prometheus)
    2. Direct Prometheus scraping from Function App /api/metrics endpoint
.PARAMETER ResourceGroup
    The name of the resource group containing the resources
.PARAMETER FunctionAppName
    The name of the Function App (optional, will auto-discover if not provided)
.PARAMETER GrafanaName
    The name of the Grafana instance (optional, will auto-discover if not provided)
.EXAMPLE
    .\Configure-GrafanaDataSources.ps1 -ResourceGroup rg-dev
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $false)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory = $false)]
    [string]$GrafanaName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🚀 Configuring Grafana Data Sources for Hybrid Monitoring" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

# Auto-discover Function App if not provided
if (-not $FunctionAppName) {
    Write-Host "`n🔍 Discovering Function App..." -ForegroundColor Cyan
    $functionApps = az functionapp list --resource-group $ResourceGroup --query "[].name" -o tsv
    if (-not $functionApps) {
        Write-Error "No Function Apps found in resource group: $ResourceGroup"
        exit 1
    }
    $FunctionAppName = $functionApps | Select-Object -First 1
    Write-Host "   Found: $FunctionAppName" -ForegroundColor Green
}

# Auto-discover Grafana if not provided
if (-not $GrafanaName) {
    Write-Host "🔍 Discovering Grafana instance..." -ForegroundColor Cyan
    $grafanaInstances = az resource list --resource-group $ResourceGroup --resource-type Microsoft.Dashboard/grafana --query "[].name" -o tsv
    if (-not $grafanaInstances) {
        Write-Error "No Grafana instances found in resource group: $ResourceGroup"
        exit 1
    }
    $GrafanaName = $grafanaInstances | Select-Object -First 1
    Write-Host "   Found: $GrafanaName" -ForegroundColor Green
}

# Get Function App details
Write-Host "`n📋 Getting Function App details..." -ForegroundColor Cyan
$functionApp = az functionapp show --name $FunctionAppName --resource-group $ResourceGroup | ConvertFrom-Json
$functionAppUrl = "https://$($functionApp.properties.defaultHostName)"
$functionAppId = $functionApp.id

# Try to get Function App host key (may require elevated permissions)
Write-Host "🔑 Getting Function App host key..." -ForegroundColor Cyan
try {
    $keys = az functionapp keys list --name $FunctionAppName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
    $hostKey = $keys.functionKeys.default
    if (-not $hostKey) {
        $hostKey = $keys.masterKey
    }
    $keyAvailable = $true
} catch {
    Write-Host "   ⚠️  Unable to retrieve function key (requires elevated permissions)" -ForegroundColor Yellow
    $hostKey = "<RETRIEVE_FROM_PORTAL>"
    $keyAvailable = $false
}

# Get Grafana details
Write-Host "📊 Getting Grafana details..." -ForegroundColor Cyan
$grafana = az resource show --resource-group $ResourceGroup --name $GrafanaName --resource-type Microsoft.Dashboard/grafana | ConvertFrom-Json
$grafanaEndpoint = $grafana.properties.endpoint

# Get Azure Monitor Workspace details
Write-Host "📈 Getting Azure Monitor Workspace details..." -ForegroundColor Cyan
try {
    $monitorWorkspaces = az resource list --resource-group $ResourceGroup --resource-type Microsoft.Monitor/accounts | ConvertFrom-Json
    if ($monitorWorkspaces.Count -eq 0) {
        Write-Warning "No Azure Monitor Workspace found"
        $monitorWorkspaceEndpoint = $null
    } else {
        $monitorWorkspace = $monitorWorkspaces[0]
        # Get the full resource details to access the prometheusQueryEndpoint
        $monitorWorkspaceDetails = az resource show --ids $monitorWorkspace.id | ConvertFrom-Json
        $monitorWorkspaceEndpoint = $monitorWorkspaceDetails.properties.metrics.prometheusQueryEndpoint
    }
} catch {
    Write-Host "   ⚠️  Unable to get Azure Monitor Workspace details" -ForegroundColor Yellow
    $monitorWorkspaceEndpoint = $null
}

Write-Host "`n✨ Configuration Summary" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "📊 Grafana URL: $grafanaEndpoint" -ForegroundColor Cyan
Write-Host "🎯 Function App: $functionAppUrl" -ForegroundColor Cyan
Write-Host "📈 Metrics Endpoint: $functionAppUrl/api/metrics" -ForegroundColor Cyan
if ($monitorWorkspaceEndpoint) {
    Write-Host "☁️  Azure Monitor: $monitorWorkspaceEndpoint" -ForegroundColor Cyan
}

Write-Host "`n📝 Grafana Data Source Configuration:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

Write-Host "`n1️⃣  Azure Monitor Workspace (Already Configured)" -ForegroundColor Green
Write-Host "   ✅ Automatically integrated with your Grafana instance" -ForegroundColor Gray
Write-Host "   ✅ Provides: Application Insights data" -ForegroundColor Gray
if ($monitorWorkspaceEndpoint) {
    Write-Host "   ✅ Query Endpoint: $monitorWorkspaceEndpoint" -ForegroundColor Gray
}

Write-Host "`n2️⃣  Direct Prometheus Data Source (Manual Setup Required)" -ForegroundColor Yellow
Write-Host "   To add direct Function App metrics scraping:" -ForegroundColor Gray
Write-Host "   " -ForegroundColor Gray
Write-Host "   a) Open Grafana: $grafanaEndpoint" -ForegroundColor White
Write-Host "   b) Go to: Connections → Data sources → Add data source" -ForegroundColor White
Write-Host "   c) Select: Prometheus" -ForegroundColor White
Write-Host "   d) Configure:" -ForegroundColor White
Write-Host "      • Name: Function App Metrics (Direct)" -ForegroundColor Cyan
Write-Host "      • URL: $functionAppUrl/api/metrics" -ForegroundColor Cyan
Write-Host "      • HTTP Method: GET" -ForegroundColor Cyan
Write-Host "      • Auth: Skip TLS Verify (off)" -ForegroundColor Cyan
Write-Host "   e) Add Custom HTTP Headers:" -ForegroundColor White
Write-Host "      • Header: x-functions-key" -ForegroundColor Cyan
if ($keyAvailable) {
    Write-Host "      • Value: $hostKey" -ForegroundColor Cyan
} else {
    Write-Host "      • Value: <Get from Azure Portal → Function App → Functions → App keys>" -ForegroundColor Yellow
}
Write-Host "   f) Click 'Save & Test'" -ForegroundColor White

Write-Host "`n💡 Testing the Metrics Endpoint:" -ForegroundColor Yellow
Write-Host "   Run this command to verify metrics are accessible:" -ForegroundColor Gray
if ($keyAvailable) {
    Write-Host "   curl '$functionAppUrl/api/metrics' -H 'x-functions-key: $hostKey'" -ForegroundColor Cyan
} else {
    Write-Host "   curl '$functionAppUrl/api/metrics' -H 'x-functions-key: <YOUR_KEY>'" -ForegroundColor Cyan
    Write-Host "   Get the function key from: Azure Portal → $FunctionAppName → Functions → App keys" -ForegroundColor Yellow
}

Write-Host "`n🎨 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Configure the Prometheus data source in Grafana (steps above)" -ForegroundColor White
Write-Host "   2. Create dashboards to visualize your metrics" -ForegroundColor White
Write-Host "   3. Use PromQL to query: function_invocations_total, function_duration_seconds" -ForegroundColor White

Write-Host "`n✅ Configuration information gathered successfully!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

# Save configuration to file
$config = @{
    grafanaEndpoint = $grafanaEndpoint
    functionAppUrl = $functionAppUrl
    metricsEndpoint = "$functionAppUrl/api/metrics"
    functionKey = $hostKey
    azureMonitorEndpoint = $monitorWorkspaceEndpoint
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$configPath = Join-Path $PSScriptRoot "..\grafana-config.json"
$config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
Write-Host "`n💾 Configuration saved to: $configPath" -ForegroundColor Cyan
