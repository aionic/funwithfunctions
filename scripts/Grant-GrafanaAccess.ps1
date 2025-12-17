#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Grants user access to Azure Managed Grafana
.DESCRIPTION
    This script grants the Grafana Admin role to a user or service principal on the Azure Managed Grafana instance.
.PARAMETER ResourceGroup
    The name of the resource group containing the Grafana instance
.PARAMETER GrafanaName
    The name of the Grafana instance (optional, will auto-discover if not provided)
.PARAMETER PrincipalId
    The object ID of the user or service principal to grant access to (optional, uses current user if not provided)
.EXAMPLE
    .\Grant-GrafanaAccess.ps1 -ResourceGroup rg-dev
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$GrafanaName,

    [Parameter(Mandatory = $false)]
    [string]$PrincipalId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🔍 Finding Grafana instance..." -ForegroundColor Cyan

# Auto-discover Grafana name if not provided
if (-not $GrafanaName) {
    $grafanaInstances = az grafana list --resource-group $ResourceGroup --query "[].name" -o tsv
    if (-not $grafanaInstances) {
        Write-Error "No Grafana instances found in resource group: $ResourceGroup"
        exit 1
    }
    $GrafanaName = $grafanaInstances | Select-Object -First 1
    Write-Host "Found Grafana instance: $GrafanaName" -ForegroundColor Green
}

# Get current user if PrincipalId not provided
if (-not $PrincipalId) {
    Write-Host "Getting current user..." -ForegroundColor Cyan
    $currentUser = az ad signed-in-user show --query id -o tsv
    $PrincipalId = $currentUser
    $userName = az ad signed-in-user show --query userPrincipalName -o tsv
    Write-Host "Current user: $userName ($PrincipalId)" -ForegroundColor Green
}

# Get Grafana resource ID
$grafanaId = az grafana show --name $GrafanaName --resource-group $ResourceGroup --query id -o tsv
if (-not $grafanaId) {
    Write-Error "Failed to get Grafana resource ID"
    exit 1
}

Write-Host "Grafana Resource ID: $grafanaId" -ForegroundColor Gray

# Check if user already has access
Write-Host "`n🔍 Checking existing role assignments..." -ForegroundColor Cyan
$existingRole = az role assignment list --assignee $PrincipalId --scope $grafanaId --query "[?roleDefinitionName=='Grafana Admin'].roleDefinitionName" -o tsv

if ($existingRole) {
    Write-Host "✅ User already has Grafana Admin role" -ForegroundColor Green
} else {
    Write-Host "📝 Granting Grafana Admin role..." -ForegroundColor Cyan
    az role assignment create `
        --assignee $PrincipalId `
        --role "Grafana Admin" `
        --scope $grafanaId

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully granted Grafana Admin role" -ForegroundColor Green
    } else {
        Write-Error "Failed to grant Grafana Admin role"
        exit 1
    }
}

# Get Grafana endpoint
$grafanaEndpoint = az grafana show --name $GrafanaName --resource-group $ResourceGroup --query properties.endpoint -o tsv

Write-Host "`n✨ Grafana Access Configuration Complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "📊 Grafana URL: $grafanaEndpoint" -ForegroundColor Cyan
Write-Host "👤 Principal ID: $PrincipalId" -ForegroundColor Cyan
Write-Host "🔐 Role: Grafana Admin" -ForegroundColor Cyan
Write-Host "`n💡 Note: It may take a few minutes for the role assignment to propagate." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
