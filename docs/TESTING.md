# Testing Guide

This document provides comprehensive testing strategies and procedures for the Azure Functions Weather API.

## Table of Contents

- [Local Testing](#local-testing)
- [Integration Testing](#integration-testing)
- [Load Testing](#load-testing)
- [Security Testing](#security-testing)
- [Monitoring Validation](#monitoring-validation)

## Local Testing

### Prerequisites

- .NET 8 SDK installed
- Azure Functions Core Tools v4
- OpenWeatherMap API key
- PowerShell 7+

### Setup

1. **Configure local settings**:
   ```json
   // src/local.settings.json
   {
     "Values": {
       "WeatherApiKey": "your-api-key-here",
       "BUILD_SOURCEVERSION": "local-test"
     }
   }
   ```

   Note: For production deployments, the API key is stored in Azure Key Vault and automatically referenced by the Function App.

2. **Start the function locally**:
   ```powershell
   cd src
   func start
   ```

### Manual Testing

#### Health Check Endpoint

```powershell
# Test health endpoint
$response = Invoke-RestMethod -Uri "http://localhost:7071/api/health"
$response

# Expected output:
# status    : healthy
# timestamp : 1703001234
# version   : local-test
```

#### Version Endpoint

```powershell
# Test version endpoint
$response = Invoke-RestMethod -Uri "http://localhost:7071/api/version"
$response

# Expected output:
# version     : 1.0.0
# gitSha      : local-test
# buildDate   : unknown
# environment : Development
```

#### Weather Endpoint

```powershell
# Test weather endpoint (function key not required locally by default)
$response = Invoke-RestMethod -Uri "http://localhost:7071/api/weather/London"
$response

# Expected output:
# city        : London
# country     : GB
# temperature : 15.5
# feelsLike   : 14.2
# description : partly cloudy
# humidity    : 72
# windSpeed   : 3.5
# timestamp   : 1703001234
```

#### Metrics Endpoint

```powershell
# Test Prometheus metrics endpoint
$metrics = Invoke-RestMethod -Uri "http://localhost:7071/api/metrics"
$metrics

# Look for metrics like:
# function_invocations_total
# function_duration_seconds
# weather_api_calls_total
```

### Error Cases

#### Invalid City

```powershell
# Test with non-existent city
try {
    $response = Invoke-RestMethod -Uri "http://localhost:7071/api/weather/InvalidCityName12345"
} catch {
    $_.Exception.Response.StatusCode  # Should be 404
}
```

#### Missing City Parameter

```powershell
# Test with empty city (if route allows)
try {
    $response = Invoke-RestMethod -Uri "http://localhost:7071/api/weather/"
} catch {
    $_.Exception.Response.StatusCode  # Should be 404 or 400
}
```

## Integration Testing

### Azure Environment Testing

Once deployed to Azure:

```powershell
# Set variables
$functionAppName = "your-function-app-name"
$functionKey = "your-function-key"
$baseUrl = "https://$functionAppName.azurewebsites.net/api"

# Test health (anonymous)
Invoke-RestMethod -Uri "$baseUrl/health"

# Test version (anonymous)
Invoke-RestMethod -Uri "$baseUrl/version"

# Test weather with function key
$weatherUrl = "$baseUrl/weather/London?code=$functionKey"
Invoke-RestMethod -Uri $weatherUrl

# Test metrics (anonymous)
Invoke-RestMethod -Uri "$baseUrl/metrics"
```

### Automated Test Script

Save as `Test-WeatherApi.ps1`:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$FunctionAppUrl,

    [Parameter(Mandatory=$false)]
    [string]$FunctionKey = "",

    [Parameter(Mandatory=$false)]
    [string[]]$Cities = @("London", "Paris", "Tokyo", "New York")
)

$results = @()

Write-Host "Testing Weather API..." -ForegroundColor Cyan

# Test 1: Health Check
Write-Host "`nTest 1: Health Check" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$FunctionAppUrl/health"
    Write-Host "✓ Health check passed: $($health.status)" -ForegroundColor Green
    $results += [PSCustomObject]@{
        Test = "Health Check"
        Status = "Pass"
        Details = $health.status
    }
} catch {
    Write-Host "✗ Health check failed: $_" -ForegroundColor Red
    $results += [PSCustomObject]@{
        Test = "Health Check"
        Status = "Fail"
        Details = $_.Exception.Message
    }
}

# Test 2: Version Info
Write-Host "`nTest 2: Version Info" -ForegroundColor Yellow
try {
    $version = Invoke-RestMethod -Uri "$FunctionAppUrl/version"
    Write-Host "✓ Version retrieved: $($version.gitSha)" -ForegroundColor Green
    $results += [PSCustomObject]@{
        Test = "Version Info"
        Status = "Pass"
        Details = $version.gitSha
    }
} catch {
    Write-Host "✗ Version retrieval failed: $_" -ForegroundColor Red
    $results += [PSCustomObject]@{
        Test = "Version Info"
        Status = "Fail"
        Details = $_.Exception.Message
    }
}

# Test 3: Weather Data
foreach ($city in $Cities) {
    Write-Host "`nTest 3.$($Cities.IndexOf($city) + 1): Weather for $city" -ForegroundColor Yellow
    try {
        $url = "$FunctionAppUrl/weather/$city"
        if ($FunctionKey) {
            $url += "?code=$FunctionKey"
        }

        $weather = Invoke-RestMethod -Uri $url
        Write-Host "✓ Weather retrieved: $($weather.temperature)°C, $($weather.description)" -ForegroundColor Green
        $results += [PSCustomObject]@{
            Test = "Weather - $city"
            Status = "Pass"
            Details = "$($weather.temperature)°C"
        }
    } catch {
        Write-Host "✗ Weather retrieval failed: $_" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Test = "Weather - $city"
            Status = "Fail"
            Details = $_.Exception.Message
        }
    }

    Start-Sleep -Milliseconds 500
}

# Test 4: Metrics
Write-Host "`nTest 4: Prometheus Metrics" -ForegroundColor Yellow
try {
    $metrics = Invoke-RestMethod -Uri "$FunctionAppUrl/metrics"
    $metricLines = ($metrics -split "`n" | Where-Object { $_ -match "^function_invocations_total" }).Count
    Write-Host "✓ Metrics endpoint working: $metricLines metric lines found" -ForegroundColor Green
    $results += [PSCustomObject]@{
        Test = "Prometheus Metrics"
        Status = "Pass"
        Details = "$metricLines lines"
    }
} catch {
    Write-Host "✗ Metrics retrieval failed: $_" -ForegroundColor Red
    $results += [PSCustomObject]@{
        Test = "Prometheus Metrics"
        Status = "Fail"
        Details = $_.Exception.Message
    }
}

# Summary
Write-Host "`n========== Test Summary ==========" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$passed = ($results | Where-Object { $_.Status -eq "Pass" }).Count
$failed = ($results | Where-Object { $_.Status -eq "Fail" }).Count

Write-Host "`nTotal: $($results.Count) | Passed: $passed | Failed: $failed" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Host "`nTests FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nAll tests PASSED" -ForegroundColor Green
    exit 0
}
```

## Load Testing

### Simple Load Test

```powershell
# Load test with concurrent requests
param(
    [int]$Requests = 100,
    [int]$Concurrent = 10
)

$url = "http://localhost:7071/api/weather/London"
$results = @()

Write-Host "Starting load test: $Requests requests, $Concurrent concurrent" -ForegroundColor Cyan

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

1..$Requests | ForEach-Object -Parallel {
    $start = Get-Date
    try {
        $response = Invoke-RestMethod -Uri $using:url
        $duration = ((Get-Date) - $start).TotalMilliseconds
        [PSCustomObject]@{
            Success = $true
            Duration = $duration
        }
    } catch {
        [PSCustomObject]@{
            Success = $false
            Duration = 0
        }
    }
} -ThrottleLimit $Concurrent | ForEach-Object {
    $results += $_
}

$stopwatch.Stop()

# Calculate statistics
$successful = ($results | Where-Object { $_.Success }).Count
$failed = ($results | Where-Object { -not $_.Success }).Count
$durations = ($results | Where-Object { $_.Success }).Duration
$avgDuration = ($durations | Measure-Object -Average).Average
$p95 = $durations | Sort-Object | Select-Object -Index ([math]::Floor($durations.Count * 0.95))
$p99 = $durations | Sort-Object | Select-Object -Index ([math]::Floor($durations.Count * 0.99))

Write-Host "`n========== Load Test Results ==========" -ForegroundColor Cyan
Write-Host "Total Requests: $Requests"
Write-Host "Successful: $successful"
Write-Host "Failed: $failed"
Write-Host "Success Rate: $([math]::Round(($successful/$Requests)*100, 2))%"
Write-Host "Total Duration: $($stopwatch.Elapsed.TotalSeconds) seconds"
Write-Host "Requests/Second: $([math]::Round($Requests/$stopwatch.Elapsed.TotalSeconds, 2))"
Write-Host "Avg Response Time: $([math]::Round($avgDuration, 2)) ms"
Write-Host "P95 Response Time: $([math]::Round($p95, 2)) ms"
Write-Host "P99 Response Time: $([math]::Round($p99, 2)) ms"
```

### Azure Load Testing

For production load testing, use [Azure Load Testing](https://learn.microsoft.com/en-us/azure/load-testing/):

```yaml
# load-test.yaml
testName: WeatherAPILoadTest
testDescription: Load test for Weather API
engineInstances: 1
testPlan: jmeter-test.jmx
failureCriteria:
  - avg(response_time_ms) > 1000
  - percentage(error) > 5
```

## Security Testing

### Authentication Testing

```powershell
# Test 1: Anonymous access to protected endpoint (should fail)
try {
    Invoke-RestMethod -Uri "https://your-app.azurewebsites.net/api/weather/London"
    Write-Host "✗ SECURITY ISSUE: Endpoint accessible without key" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "✓ Authentication working: 401 Unauthorized" -ForegroundColor Green
    }
}

# Test 2: Invalid function key (should fail)
try {
    Invoke-RestMethod -Uri "https://your-app.azurewebsites.net/api/weather/London?code=invalid"
    Write-Host "✗ SECURITY ISSUE: Invalid key accepted" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "✓ Key validation working: 401 Unauthorized" -ForegroundColor Green
    }
}

# Test 3: Valid function key (should succeed)
$validKey = "your-valid-key"
try {
    $response = Invoke-RestMethod -Uri "https://your-app.azurewebsites.net/api/weather/London?code=$validKey"
    Write-Host "✓ Valid authentication: Data retrieved" -ForegroundColor Green
} catch {
    Write-Host "✗ Valid key rejected" -ForegroundColor Red
}
```

### HTTPS Enforcement

```powershell
# Test HTTP redirect to HTTPS
try {
    Invoke-WebRequest -Uri "http://your-app.azurewebsites.net/api/health" -MaximumRedirection 0
} catch {
    if ($_.Exception.Response.StatusCode -eq 301 -or $_.Exception.Response.StatusCode -eq 307) {
        Write-Host "✓ HTTPS redirect working" -ForegroundColor Green
    }
}
```

## Monitoring Validation

### Application Insights

```powershell
# Query Application Insights
az monitor app-insights query `
    --app <app-insights-name> `
    --analytics-query "requests | where timestamp > ago(1h) | summarize count() by resultCode"
```

### Prometheus Metrics Validation

```powershell
# Fetch and validate metrics
$metrics = Invoke-RestMethod -Uri "https://your-app.azurewebsites.net/api/metrics"

# Check for required metrics
$requiredMetrics = @(
    "function_invocations_total",
    "function_duration_seconds",
    "weather_api_calls_total",
    "weather_api_duration_seconds"
)

foreach ($metric in $requiredMetrics) {
    if ($metrics -match $metric) {
        Write-Host "✓ Metric found: $metric" -ForegroundColor Green
    } else {
        Write-Host "✗ Metric missing: $metric" -ForegroundColor Red
    }
}
```

### Grafana Dashboard

1. Navigate to Azure Managed Grafana endpoint
2. Add Prometheus data source pointing to Function App metrics endpoint
3. Import dashboard or create custom panels
4. Validate data is flowing

### Log Analytics Queries

```kql
// Function invocations in last hour
FunctionAppLogs
| where TimeGenerated > ago(1h)
| where Category == "Function"
| summarize count() by FunctionName, bin(TimeGenerated, 5m)

// Error rate
FunctionAppLogs
| where TimeGenerated > ago(1h)
| where Level == "Error"
| summarize ErrorCount = count() by FunctionName

// Performance metrics
FunctionAppLogs
| where TimeGenerated > ago(1h)
| where Category == "Function"
| extend Duration = todouble(Properties.Duration)
| summarize
    AvgDuration = avg(Duration),
    P95Duration = percentile(Duration, 95),
    P99Duration = percentile(Duration, 99)
    by FunctionName
```

## Continuous Testing

### GitHub Actions Test Workflow

The project includes automated tests in `.github/workflows/dotnet-build.yml`:

- Build verification
- Unit tests (if present)
- Integration tests
- Security scans

### Post-Deployment Testing

After each deployment:

1. Run automated test suite
2. Validate version endpoint shows correct SHA
3. Check Application Insights for errors
4. Verify metrics are being collected
5. Test all endpoints manually

## Troubleshooting

### Common Issues

**Issue**: Function returns 500 error
- Check Application Insights for exceptions
- Verify WeatherApiKey is configured
- Check network connectivity from VNet

**Issue**: No metrics appearing
- Verify `/api/metrics` endpoint is accessible
- Check Prometheus scrape configuration
- Review function logs for metric export errors

**Issue**: Storage account connection fails
- Verify managed identity is assigned
- Check role assignments on storage
- Confirm private endpoint DNS resolution

## Test Data

### Sample Cities

- London, GB
- Paris, FR
- Tokyo, JP
- New York, US
- Sydney, AU

### Expected Response Times

- Health Check: < 50ms
- Version Info: < 50ms
- Weather API (cached): < 100ms
- Weather API (uncached): < 500ms
- Metrics: < 200ms

## References

- [Azure Functions Testing Guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-test-a-function)
- [Prometheus Testing](https://prometheus.io/docs/practices/pushing/)
- [Application Insights Testing](https://learn.microsoft.com/en-us/azure/azure-monitor/app/availability-overview)
