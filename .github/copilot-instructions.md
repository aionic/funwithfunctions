# Azure Functions Weather API - Project Instructions

This is an Azure Functions .NET 8 isolated worker project with Flex Consumption plan.

## Project Overview
- **Function App**: HTTP-triggered weather API with function key authentication
- **Versioning**: GitHub SHA stamped on deployments with dedicated version endpoint
- **Monitoring**: Application Insights + Prometheus metrics + Azure Managed Grafana
- **Infrastructure**: Bicep with private endpoints, VNet, managed identity
- **Deployment**: Azure Developer CLI (azd) and GitHub Actions

## Key Technologies
- .NET 8 isolated worker model
- Azure Functions Flex Consumption plan
- Prometheus.NET for metrics
- Azure Managed Grafana
- OpenAPI/Swagger specification
- Microsoft native tooling (latest packages)

## Project Structure
- `/src` - .NET function application code
- `/infra` - Bicep infrastructure as code
- `/docs` - Architecture and testing documentation
- `/scripts` - Demo and testing PowerShell scripts
- `/.github/workflows` - CI/CD pipelines
