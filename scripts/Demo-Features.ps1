# Azure Functions Weather API - Feature Demo Script
# This script demonstrates all features of the Weather API

param(
    [Parameter(Mandatory=$false)]
    [string]$FunctionAppUrl = "http://localhost:7071/api",

    [Parameter(Mandatory=$false)]
    [string]$FunctionKey = ""
)

$ErrorActionPreference = "Continue"

function Write-DemoHeader {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n→ " -NoNewline -ForegroundColor Green
    Write-Host $Message -ForegroundColor White
}

function Write-Output {
    param($Data, [string]$Format = "json")
    Write-Host "`n" -NoNewline
    if ($Format -eq "json") {
        $Data | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor DarkCyan
    } else {
        $Data | Write-Host -ForegroundColor DarkCyan
    }
}

function Pause-Demo {
    Write-Host "`nPress any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Demo Banner
Clear-Host
Write-Host @"

    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║       AZURE FUNCTIONS WEATHER API - FEATURE DEMO         ║
    ║                                                           ║
    ║       Production-Ready Serverless API with:              ║
    ║       • Prometheus Metrics                                ║
    ║       • Application Insights Integration                  ║
    ║       • Git SHA Version Tracking                          ║
    ║       • Private Endpoint Security                         ║
    ║       • Managed Identity Authentication                   ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "  Target API: " -NoNewline -ForegroundColor Gray
Write-Host $FunctionAppUrl -ForegroundColor White
Write-Host "  Demo Time: " -NoNewline -ForegroundColor Gray
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host ""

Pause-Demo

# Feature 1: Health Check
Write-DemoHeader "Feature 1: Health Check Endpoint (Anonymous Access)"

Write-Step "The health check endpoint provides real-time status of the API"
Write-Host "  • No authentication required" -ForegroundColor Gray
Write-Host "  • Returns status, timestamp, and version" -ForegroundColor Gray
Write-Host "  • Ideal for load balancer health probes" -ForegroundColor Gray

Write-Step "Calling GET /api/health..."
try {
    $health = Invoke-RestMethod -Uri "$FunctionAppUrl/health" -Method Get
    Write-Output $health
    Write-Host "`n✓ API is " -NoNewline -ForegroundColor Green
    Write-Host $health.status.ToUpper() -ForegroundColor Green -NoNewline
    Write-Host " and responding" -ForegroundColor Green
} catch {
    Write-Host "✗ Health check failed: $_" -ForegroundColor Red
}

Pause-Demo

# Feature 2: Version Information with Git SHA
Write-DemoHeader "Feature 2: Version Tracking with Git SHA Stamping"

Write-Step "Every deployment is tagged with the Git commit SHA"
Write-Host "  • Enables version traceability" -ForegroundColor Gray
Write-Host "  • Links deployments to source code" -ForegroundColor Gray
Write-Host "  • Stamped during CI/CD build process" -ForegroundColor Gray

Write-Step "Calling GET /api/version..."
try {
    $version = Invoke-RestMethod -Uri "$FunctionAppUrl/version" -Method Get
    Write-Output $version

    Write-Host "`n📦 Deployment Information:" -ForegroundColor Cyan
    Write-Host "  Version: " -NoNewline -ForegroundColor Gray
    Write-Host $version.version -ForegroundColor White
    Write-Host "  Git SHA: " -NoNewline -ForegroundColor Gray
    Write-Host $version.gitSha -ForegroundColor Yellow
    Write-Host "  Build Date: " -NoNewline -ForegroundColor Gray
    Write-Host $version.buildDate -ForegroundColor White
    Write-Host "  Environment: " -NoNewline -ForegroundColor Gray
    Write-Host $version.environment -ForegroundColor White
} catch {
    Write-Host "✗ Version check failed: $_" -ForegroundColor Red
}

Pause-Demo

# Feature 3: Prometheus Metrics
Write-DemoHeader "Feature 3: Prometheus Metrics Integration"

Write-Step "The API exposes Prometheus-compatible metrics for monitoring"
Write-Host "  • Custom business metrics (weather API calls)" -ForegroundColor Gray
Write-Host "  • Performance metrics (latency, duration)" -ForegroundColor Gray
Write-Host "  • Ready for Grafana visualization" -ForegroundColor Gray

Write-Step "Calling GET /api/metrics..."
try {
    $metrics = Invoke-RestMethod -Uri "$FunctionAppUrl/metrics" -Method Get

    # Parse metrics
    $metricLines = $metrics -split "`n"
    $functionMetrics = $metricLines | Where-Object { $_ -match "^function_" }
    $weatherMetrics = $metricLines | Where-Object { $_ -match "^weather_" }

    Write-Host "`n📊 Metrics Summary:" -ForegroundColor Cyan
    Write-Host "  Total metric lines: $($metricLines.Count)" -ForegroundColor White
    Write-Host "  Function metrics: $($functionMetrics.Count)" -ForegroundColor White
    Write-Host "  Weather API metrics: $($weatherMetrics.Count)" -ForegroundColor White

    Write-Host "`n Sample Metrics:" -ForegroundColor Cyan
    $metricLines | Select-Object -First 20 | Write-Host -ForegroundColor DarkGray
    Write-Host "  ... (truncated)" -ForegroundColor Gray

} catch {
    Write-Host "✗ Metrics retrieval failed: $_" -ForegroundColor Red
}

Pause-Demo

# Feature 4: Weather API Integration
Write-DemoHeader "Feature 4: Weather Data Retrieval with Function Key Auth"

Write-Step "The weather endpoint demonstrates:"
Write-Host "  • Integration with external APIs (OpenWeatherMap)" -ForegroundColor Gray
Write-Host "  • Function key authentication" -ForegroundColor Gray
Write-Host "  • Structured error handling" -ForegroundColor Gray
Write-Host "  • Automatic metrics collection" -ForegroundColor Gray

$cities = @("London", "Paris", "Tokyo")

foreach ($city in $cities) {
    Write-Step "Fetching weather for $city..."

    try {
        $url = "$FunctionAppUrl/weather/$([uri]::EscapeDataString($city))"
        if ($FunctionKey) {
            $url += "?code=$FunctionKey"
        }

        $weather = Invoke-RestMethod -Uri $url -Method Get

        Write-Host "`n🌤  Weather in " -NoNewline -ForegroundColor Cyan
        Write-Host "$($weather.city), $($weather.country)" -ForegroundColor Yellow
        Write-Host "  Temperature: " -NoNewline -ForegroundColor Gray
        Write-Host "$($weather.temperature)°C" -ForegroundColor White -NoNewline
        Write-Host " (feels like " -ForegroundColor Gray -NoNewline
        Write-Host "$($weather.feelsLike)°C" -ForegroundColor White -NoNewline
        Write-Host ")" -ForegroundColor Gray
        Write-Host "  Conditions: " -NoNewline -ForegroundColor Gray
        Write-Host $weather.description -ForegroundColor White
        Write-Host "  Humidity: " -NoNewline -ForegroundColor Gray
        Write-Host "$($weather.humidity)%" -ForegroundColor White
        Write-Host "  Wind Speed: " -NoNewline -ForegroundColor Gray
        Write-Host "$($weather.windSpeed) m/s" -ForegroundColor White

    } catch {
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Host "`n🔒 Authentication Required" -ForegroundColor Yellow
            Write-Host "  The weather endpoint requires a function key for security" -ForegroundColor Gray
            Write-Host "  Run with: " -NoNewline -ForegroundColor Gray
            Write-Host "./Demo-Features.ps1 -FunctionKey 'your-key'" -ForegroundColor White
            break
        } else {
            Write-Host "✗ Failed to fetch weather: $_" -ForegroundColor Red
        }
    }

    Start-Sleep -Milliseconds 500
}

Pause-Demo

# Feature 5: Monitoring & Observability
Write-DemoHeader "Feature 5: Comprehensive Monitoring & Observability"

Write-Host @"

The API includes enterprise-grade monitoring:

📊 Application Insights:
  • Request telemetry and tracking
  • Dependency tracking (HTTP calls to weather API)
  • Exception logging and diagnostics
  • Performance counters and metrics
  • Distributed tracing (W3C standard)
  • Live metrics stream

📈 Prometheus Metrics:
  • function_invocations_total - Count of function calls by status
  • function_duration_seconds - Function execution time
  • weather_api_calls_total - External API call tracking
  • weather_api_duration_seconds - External API latency

📉 Azure Managed Grafana:
  • Pre-configured dashboards
  • Real-time metric visualization
  • Alert configuration
  • Custom query support

🔍 Log Analytics:
  • Centralized log aggregation
  • KQL query support
  • 30-day retention
  • Integration with Azure Monitor

"@ -ForegroundColor White

Pause-Demo

# Feature 6: Security Architecture
Write-DemoHeader "Feature 6: Security Features"

Write-Host @"

The API implements multiple security layers:

🔐 Authentication & Authorization:
  • Function key authentication for weather endpoint
  • Anonymous access for health/version/metrics
  • Azure AD integration ready

🌐 Network Security:
  • Private endpoints for storage account
  • VNet integration for function app
  • Public network access disabled on storage
  • TLS 1.2 minimum enforced

🔑 Identity Management:
  • User-assigned managed identity
  • Passwordless authentication to Azure services
  • Role-based access control (RBAC)
  • No connection strings or keys in code

🛡  Data Protection:
  • HTTPS only (HTTP redirects to HTTPS)
  • Storage encryption at rest
  • Secrets management via app settings
  • Key Vault integration ready

"@ -ForegroundColor White

Pause-Demo

# Feature 7: Deployment Architecture
Write-DemoHeader "Feature 7: CI/CD & Deployment"

Write-Host @"

Automated deployment pipeline:

🔄 GitHub Actions Workflows:
  1. Build & Test (.NET compilation, unit tests)
  2. Bicep Validation (infrastructure linting)
  3. Deploy Infrastructure (ARM deployment with versioning)
  4. Deploy Application (function app deployment)

📦 Azure Developer CLI (azd):
  • One-command deployment (azd up)
  • Environment management
  • Infrastructure as Code (Bicep)
  • Automatic configuration

🏷  Version Stamping:
  • Git SHA injected during build
  • Available via /api/version endpoint
  • Tracked in Application Insights
  • Linked to source code commits

📁 Project Structure:
  • /src - .NET 8 function code
  • /infra - Bicep infrastructure templates
  • /docs - Architecture documentation
  • /scripts - Testing and demo scripts
  • /.github/workflows - CI/CD pipelines

"@ -ForegroundColor White

Pause-Demo

# Demo Complete
Write-DemoHeader "Demo Complete!"

Write-Host @"

🎉 You've seen all the key features!

Next Steps:
  1. Review the architecture: docs/ARCHITECTURE.md
  2. Run tests: ./scripts/Test-WeatherApi.ps1
  3. Deploy to Azure: azd up
  4. Configure Grafana dashboards
  5. Set up alerts in Azure Monitor

Resources:
  • README.md - Getting started guide
  • docs/TESTING.md - Comprehensive testing guide
  • docs/swagger.json - OpenAPI specification
  • GitHub repo - Source code and issues

"@ -ForegroundColor White

Write-Host "Thank you for exploring the Azure Functions Weather API! 🚀" -ForegroundColor Cyan
Write-Host ""
