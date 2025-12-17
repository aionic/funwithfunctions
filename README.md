# Azure Functions Weather API

![Fun with Functions](./fun-with-function.png)

A production-ready Azure Functions application demonstrating best practices for serverless APIs with comprehensive monitoring, security, and observability features.

## 🌟 Features

- **⚡ Serverless Architecture**: Built on Azure Functions Flex Consumption plan for automatic scaling
- **🔒 Secure by Design**: Private endpoints for storage, managed identity authentication, function key authorization
- **📊 Comprehensive Monitoring**: Application Insights, Prometheus metrics, and Azure Managed Grafana integration
- **🔄 CI/CD Ready**: GitHub Actions workflows for automated build, test, and deployment
- **📝 API Documentation**: Complete OpenAPI/Swagger specification
- **🏷️ Version Tracking**: Git SHA stamping on every deployment with dedicated version endpoint

## 🏗️ Architecture

See [ARCHITECTURE.md](./docs/ARCHITECTURE.md) for detailed architecture documentation.

### Key Components

- **.NET 8 Isolated Worker**: Modern Azure Functions runtime
- **Virtual Network**: Private connectivity for secure resource access
- **Private Endpoints**: Storage account secured behind VNet
- **Managed Identity**: Passwordless authentication to Azure resources
- **Prometheus**: Custom metrics collection and export
- **Azure Managed Grafana**: Visualization and dashboarding

## 🚀 Getting Started

### Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [PowerShell 7+](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- Weather API Key (see [Weather Provider Options](#weather-provider-options))

### Local Development

1. **Clone the repository**
   ```powershell
   git clone <repository-url>
   cd funwithfunctions
   ```

2. **Configure local settings**

   **Option A: Using .env file (Recommended)**

   The API key from your `.env` file will work for Azure deployment. For local development, create `src/local.settings.json`:
   ```json
   {
     "Values": {
       "WeatherApiKey": "xxxxxxxxxxxxxxxxxx"
     }
   }
   ```

   **Option B: Manual configuration**

   Update `src/local.settings.json` with your weather API key directly.

   See [Weather Provider Options](#weather-provider-options) for obtaining an API key.

3. **Restore dependencies**
   ```powershell
   dotnet restore ./src/WeatherFunction.csproj
   ```

4. **Run locally**
   ```powershell
   cd src
   func start
   ```

5. **Test the endpoints**
   ```powershell
   # Health check (anonymous)
   Invoke-RestMethod -Uri "http://localhost:7071/api/health"

   # Version info (anonymous)
   Invoke-RestMethod -Uri "http://localhost:7071/api/version"

   # Weather data (requires function key - use default local key)
   Invoke-RestMethod -Uri "http://localhost:7071/api/weather/London"

   # Prometheus metrics (anonymous)
   Invoke-RestMethod -Uri "http://localhost:7071/api/metrics"
   ```

## 📦 Deployment

### Using Azure Developer CLI (azd)

The recommended deployment method using `azd`:

1. **Create .env file with your API key**

   Create a `.env` file in the project root:
   ```bash
   WEATHER_API_KEY=your-api-key-here
   ```

   The `.env` file is already in `.gitignore` - safe to store secrets locally.

2. **Initialize azd environment**
   ```powershell
   azd init
   ```

3. **Login to Azure**
   ```powershell
   azd auth login
   ```

4. **Set environment variables**
   ```powershell
   azd env set AZURE_LOCATION westus3
   ```

5. **Deploy**
   ```powershell
   azd up
   ```

This will:
- Provision all Azure resources (VNet, Storage, Function App, Key Vault, Monitoring)
- Build and deploy the function code
- **Automatically read your API key from .env and store it in Key Vault**
- Configure all settings and connections
- Stamp the deployment with the current Git SHA

The `azd up` command runs a post-provision hook that:
1. Reads `WEATHER_API_KEY` from your local `.env` file
2. Securely stores it in Azure Key Vault
3. Function App retrieves it using managed identity (no secrets in config!)

### Using GitHub Actions

1. **Configure secrets** in your GitHub repository:
   - `AZURE_CREDENTIALS`: Azure service principal credentials
   - `AZURE_LOCATION`: Target Azure region (e.g., 'westus3')
   - `AZURE_FUNCTIONAPP_PUBLISH_PROFILE`: Function App publish profile

2. **Trigger deployment**:
   - Push to `main` branch, or
   - Manually trigger the "Deploy to Azure" workflow

## 📖 API Endpoints

### Weather API

- **GET** `/api/weather/{city}` - Get weather for a city (requires function key)
  - Example: `/api/weather/London?code={function-key}`
  - Response: Current weather data including temperature, humidity, wind speed

### System Endpoints

- **GET** `/api/version` - Get version and build information (anonymous)
  - Returns: Git SHA, build date, environment

- **GET** `/api/health` - Health check endpoint (anonymous)
  - Returns: Health status and timestamp

### Monitoring Endpoints

- **GET** `/api/metrics` - Prometheus metrics (anonymous)
  - Returns: Metrics in Prometheus text format

## 🔐 Security

- **Function Key Authentication**: Weather endpoint requires function key
- **Azure Key Vault**: Secrets stored in Key Vault, referenced by Function App
- **Managed Identity**: Function App uses managed identity to access Key Vault and Storage
- **Private Endpoints**: Storage account accessible only via VNet
- **HTTPS Only**: All traffic encrypted in transit
- **TLS 1.2+**: Minimum TLS version enforced
- **Public Access Disabled**: Storage account denies public network access
- **RBAC Authorization**: Key Vault uses Azure RBAC for access control

## 📊 Monitoring & Observability

### Application Insights

- Request telemetry
- Dependency tracking
- Exception logging
- Performance metrics
- Distributed tracing (W3C)

### Prometheus Metrics

- `function_invocations_total` - Function call counts by status
- `function_duration_seconds` - Function execution duration
- `weather_api_calls_total` - External API call counts
- `weather_api_duration_seconds` - External API latency

### Azure Managed Grafana

Access the Grafana dashboard URL from deployment outputs to visualize:
- Function performance metrics
- Weather API call patterns
- Error rates and trends
- System health indicators

## 🛠️ Development

### Project Structure

```
funwithfunctions/
├── .github/
│   └── workflows/          # GitHub Actions CI/CD
├── docs/                   # Documentation
│   ├── ARCHITECTURE.md
│   ├── TESTING.md
│   └── swagger.json
├── infra/                  # Bicep IaC
│   ├── main.bicep
│   ├── main.bicepparam
│   └── modules/
│       ├── core.bicep
│       ├── function-app.bicep
│       └── monitoring.bicep
├── scripts/                # Demo and testing scripts
│   ├── Test-WeatherApi.ps1
│   └── Demo-Features.ps1
└── src/                    # Function app code
    ├── Functions/
    ├── Models/
    ├── Services/
    ├── Program.cs
    ├── host.json
    └── WeatherFunction.csproj
```

### Building

```powershell
dotnet build ./src/WeatherFunction.csproj --configuration Release
```

### Testing

See [TESTING.md](./docs/TESTING.md) for comprehensive testing guide.

## 📝 Configuration

### Application Settings

| Setting | Description | Required |
|---------|-------------|----------|
| `WeatherApiKey` | Weather API key (stored in Key Vault) | Yes |
| `WeatherApiBaseUrl` | Weather API base URL | No (has default) |
| `BUILD_SOURCEVERSION` | Git SHA (auto-set) | No |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Insights connection | Yes (auto-configured) |

### Weather Provider Options

This application is configured to work with OpenWeatherMap by default, but we recommend **WeatherAPI.com** as an alternative that doesn't require payment information:

#### Recommended: WeatherAPI.com (No Payment Info Required)
- **Website**: <https://www.weatherapi.com/>
- **Free Tier**: 1 million calls/month, no credit card required
- **Features**: Current weather, forecast, astronomy, sports, and more
- **Setup**:
  1. Sign up at <https://www.weatherapi.com/signup.aspx>
  2. Get your API key from the dashboard (instant activation)
  3. Update `WeatherApiBaseUrl` to `https://api.weatherapi.com/v1`
  4. Modify the service code to use WeatherAPI.com's response format

#### OpenWeatherMap (Payment Info Required)
- **Website**: <https://openweathermap.org/>
- **Free Tier**: 1,000 calls/day, requires credit card
- **Features**: Current weather, forecasts, historical data
- **Setup**:
  1. Sign up at <https://openweathermap.org/api>
  2. Add payment method (won't be charged for free tier)
  3. Get your API key
  4. Store in Key Vault (production) or local.settings.json (development)

#### Other Options
- **Open-Meteo**: Free, no API key required (<https://open-meteo.com/>)
- **7Timer!**: Free astronomy and weather data (<https://www.7timer.info/>)
- **wttr.in**: Simple weather API (<https://wttr.in/>)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Resources

- [Azure Functions Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/)
- [.NET 8 Isolated Worker Guide](https://learn.microsoft.com/en-us/azure/azure-functions/dotnet-isolated-process-guide)
- [Azure Functions Flex Consumption Plan](https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan)
- [Prometheus .NET Client](https://github.com/prometheus-net/prometheus-net)
- [Azure Managed Grafana](https://learn.microsoft.com/en-us/azure/managed-grafana/)

## 📧 Support

For issues and questions:
- Open an issue on GitHub
- Review the documentation in `/docs`
- Check Application Insights logs in Azure Portal
