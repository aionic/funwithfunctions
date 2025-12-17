#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets secrets in Azure Key Vault from local .env file
.DESCRIPTION
    This script is called by azd after infrastructure provisioning to populate
    Key Vault with secrets from the local .env file.
.PARAMETER KeyVaultName
    Name of the Azure Key Vault
.PARAMETER EnvFilePath
    Path to the .env file (defaults to .env in repo root)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory=$false)]
    [string]$EnvFilePath = ".env"
)

Write-Host "Setting Key Vault secrets from .env file..." -ForegroundColor Cyan

# Check if .env file exists
if (-not (Test-Path $EnvFilePath)) {
    Write-Warning ".env file not found at: $EnvFilePath"
    Write-Warning "Skipping Key Vault secret configuration. Please create .env file with WEATHER_API_KEY."
    exit 0
}

# Read .env file and extract WEATHER_API_KEY
$weatherApiKey = Get-Content $EnvFilePath | Where-Object { $_ -match '^WEATHER_API_KEY=' } | ForEach-Object {
    $_ -replace '^WEATHER_API_KEY=', ''
}

if ([string]::IsNullOrWhiteSpace($weatherApiKey)) {
    Write-Warning "WEATHER_API_KEY not found in .env file"
    Write-Warning "Please add 'WEATHER_API_KEY=your-key-here' to .env file"
    exit 0
}

Write-Host "Found WEATHER_API_KEY in .env file" -ForegroundColor Green

# Set the secret in Key Vault
try {
    Write-Host "Setting WeatherApiKey secret in Key Vault: $KeyVaultName" -ForegroundColor Yellow

    az keyvault secret set `
        --vault-name $KeyVaultName `
        --name "WeatherApiKey" `
        --value $weatherApiKey `
        --output none

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully set WeatherApiKey secret in Key Vault" -ForegroundColor Green
    } else {
        Write-Error "Failed to set Key Vault secret. Exit code: $LASTEXITCODE"
        exit 1
    }
}
catch {
    Write-Error "Error setting Key Vault secret: $_"
    exit 1
}

Write-Host "`nKey Vault configuration complete!" -ForegroundColor Green
Write-Host "The Function App will automatically retrieve the secret using managed identity." -ForegroundColor Cyan
