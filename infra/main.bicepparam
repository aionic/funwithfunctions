using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
param location = readEnvironmentVariable('AZURE_LOCATION', 'westus3')
param principalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')
param gitSha = readEnvironmentVariable('BUILD_SOURCEVERSION', 'local-dev')
