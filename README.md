# Azure Functions Weather API

![Fun with Functions](./fun-with-functions.png)

A production-ready Azure Functions application demonstrating serverless API best practices with comprehensive monitoring and security.

[![CI](https://github.com/aionic/funwithfunctions/actions/workflows/ci.yml/badge.svg)](https://github.com/aionic/funwithfunctions/actions/workflows/ci.yml)
[![Build and Test .NET](https://github.com/aionic/funwithfunctions/actions/workflows/dotnet-build.yml/badge.svg)](https://github.com/aionic/funwithfunctions/actions/workflows/dotnet-build.yml)
[![Validate Bicep](https://github.com/aionic/funwithfunctions/actions/workflows/bicep-validate.yml/badge.svg)](https://github.com/aionic/funwithfunctions/actions/workflows/bicep-validate.yml)
[![codecov](https://codecov.io/gh/aionic/funwithfunctions/branch/main/graph/badge.svg)](https://codecov.io/gh/aionic/funwithfunctions)

## Features

- ⚡ **Azure Functions Flex Consumption** - Automatic scaling with .NET 8 isolated worker
- 🔒 **Security** - Private endpoints, managed identity, Key Vault secrets
- 📊 **Observability** - Application Insights + Prometheus + Grafana (auto-configured)
- 🔄 **CI/CD** - GitHub Actions with unit tests and code coverage
- 🏷️ **Versioning** - Git SHA stamped on every deployment

## Architecture

**📖 [Detailed Architecture Documentation](./docs/ARCHITECTURE.md)**

**Key Components:** Azure Functions (Flex) • VNet + Private Endpoints • App Insights • Azure Monitor Workspace • Managed Grafana • Key Vault

## Quick Start

### Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Azure Functions Core Tools](https://docs.microsoft.com/azure/azure-functions/functions-run-local)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- Weather API Key ([WeatherAPI.com](https://www.weatherapi.com) recommended - no payment required)

### Local Development

```powershell
# Clone and setup
git clone <repository-url>
cd funwithfunctions

# Create local settings: src/local.settings.json
# {
#   "Values": {
#     "WeatherApiKey": "your-api-key"
#   }
# }

# Run
dotnet restore ./src
cd src && func start
```

**Test endpoints:** `http://localhost:7071/api/health` • `/api/version` • `/api/metrics` • `/api/weather/London`

## Deployment

### Azure Developer CLI (Recommended)

```powershell
# Create .env file with your API key
echo "WEATHER_API_KEY=your-api-key" > .env

# Deploy everything
azd auth login
azd up
```

**What happens:**

- ✅ Provisions all infrastructure (VNet, Storage, Functions, Key Vault, Monitoring)
- ✅ Deploys function code with Git SHA version stamp
- ✅ Stores API key securely in Key Vault
- ✅ Configures Application Insights and Grafana

### CI/CD via GitHub Actions

Configured workflows: **Bicep Validation** • **Build & Test** • **Code Coverage**

See [GitHub Actions](./.github/workflows/) for automated deployment setup.

## API Endpoints

| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /api/weather/{city}` | Function Key | Weather data for specified city |
| `GET /api/version` | Anonymous | Git SHA, build date, environment |
| `GET /api/health` | Anonymous | Health status check |
| `GET /api/metrics` | Anonymous | Prometheus metrics (text format) |

**📖 [OpenAPI Specification](./docs/swagger.json)**

## Testing

```powershell
# Run all tests
dotnet test

# With coverage
dotnet test --collect:"XPlat Code Coverage"
```

**Test Stack:** xUnit • FluentAssertions • Moq • Codecov

**📖 [Testing Guide](./docs/TESTING.md)**

## Security

✅ Function key auth for weather API
✅ Secrets in Key Vault (no hardcoded keys)
✅ Managed identity for Azure resources
✅ Private endpoints for storage
✅ HTTPS/TLS 1.2+ enforced
✅ RBAC-based access control

## Monitoring

### Automatic Setup

After `azd up`, all monitoring is auto-configured:

**Application Insights** → Real-time telemetry and distributed tracing
**Azure Monitor Workspace** → Aggregates Prometheus metrics from `/api/metrics`
**Azure Managed Grafana** → Pre-connected to Azure Monitor Workspace

### Access Grafana

```bash
# Get Grafana URL
az grafana show -n <grafana-name> -g rg-dev --query properties.endpoint -o tsv
```

1. Open Grafana URL in browser
2. Azure Monitor Workspace data source is **already configured**
3. Create dashboards using Prometheus queries

### Available Metrics

**Custom:** `function_invocations_total`, `function_duration_seconds`
**Runtime:** GC stats, memory, CPU, HTTP connections
**Framework:** ASP.NET Core, Kestrel, System.Net metrics

### Alternative: Direct Prometheus Scraping

If you prefer scraping metrics directly (instead of via Azure Monitor):

1. Deploy a Prometheus server
2. Configure it to scrape `https://your-function-app.azurewebsites.net/api/metrics`
3. Connect Grafana to your Prometheus instance

**Note:** The `/api/metrics` endpoint exports metrics in Prometheus text format but doesn't provide the Prometheus query API that Grafana needs. Azure Monitor Workspace handles this automatically.

**📖 [Grafana Setup Details](./docs/GRAFANA-SETUP.md)**

## Project Structure

```text
├── .github/workflows/      # CI/CD pipelines
├── docs/                   # Architecture, testing, API docs
├── infra/                  # Bicep infrastructure as code
│   └── modules/           # Modular Bicep templates
├── scripts/               # Demo and testing scripts
├── src/                   # Function app (.NET 8)
│   ├── Functions/         # HTTP trigger functions
│   ├── Models/           # Data models
│   └── Services/         # Business logic
└── tests/                # Unit tests (xUnit)
```

## Configuration

### Weather API Providers

**Recommended: [WeatherAPI.com](https://www.weatherapi.com)** - 1M calls/month, no credit card required

**Alternatives:**

- [OpenWeatherMap](https://openweathermap.org) - 1K calls/day, requires payment info
- [Open-Meteo](https://open-meteo.com) - Free, no API key

### Application Settings

| Setting | Source | Notes |
|---------|--------|-------|
| `WeatherApiKey` | Key Vault | Set via `.env` file during deployment |
| `BUILD_SOURCEVERSION` | Auto-set | Git SHA from deployment |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Auto-configured | Managed identity auth |

## Resources

**Documentation:** [Architecture](./docs/ARCHITECTURE.md) • [Testing](./docs/TESTING.md) • [Grafana Setup](./docs/GRAFANA-SETUP.md) • [API Spec](./docs/swagger.json)

**Microsoft Learn:**
[Azure Functions](https://learn.microsoft.com/azure/azure-functions/) • [Flex Consumption](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan) • [.NET Isolated](https://learn.microsoft.com/azure/azure-functions/dotnet-isolated-process-guide) • [Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/)

## License

MIT License
