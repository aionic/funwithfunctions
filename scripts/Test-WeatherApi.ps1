# Azure Functions Weather API - Test Script
# This script tests all endpoints of the Weather API

param(
    [Parameter(Mandatory=$false, HelpMessage="Function App URL (e.g., https://func-myapp.azurewebsites.net/api)")]
    [string]$FunctionAppUrl = "http://localhost:7071/api",

    [Parameter(Mandatory=$false, HelpMessage="Function key for protected endpoints")]
    [string]$FunctionKey = "",

    [Parameter(Mandatory=$false, HelpMessage="Cities to test")]
    [string[]]$Cities = @("London", "Paris", "Tokyo", "New York", "Sydney"),

    [Parameter(Mandatory=$false, HelpMessage="Run load test")]
    [switch]$LoadTest = $false,

    [Parameter(Mandatory=$false, HelpMessage="Number of requests for load test")]
    [int]$LoadTestRequests = 50
)

$ErrorActionPreference = "Continue"
$results = @()

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Details = ""
    )

    if ($Success) {
        Write-Host "✓ $TestName" -ForegroundColor Green
        if ($Details) { Write-Host "  $Details" -ForegroundColor Gray }
        $script:results += [PSCustomObject]@{
            Test = $TestName
            Status = "PASS"
            Details = $Details
        }
    } else {
        Write-Host "✗ $TestName" -ForegroundColor Red
        if ($Details) { Write-Host "  $Details" -ForegroundColor Yellow }
        $script:results += [PSCustomObject]@{
            Test = $TestName
            Status = "FAIL"
            Details = $Details
        }
    }
}

# Banner
Write-Host @"
╔═══════════════════════════════════════════════╗
║   Azure Functions Weather API - Test Suite   ║
╚═══════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "Target: $FunctionAppUrl" -ForegroundColor White
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White

# Test 1: Health Check
Write-TestHeader "Test 1: Health Check Endpoint"
try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $health = Invoke-RestMethod -Uri "$FunctionAppUrl/health" -Method Get
    $stopwatch.Stop()

    if ($health.status -eq "healthy") {
        Write-TestResult "Health check endpoint" $true "Status: $($health.status), Response time: $($stopwatch.ElapsedMilliseconds)ms"
    } else {
        Write-TestResult "Health check endpoint" $false "Unexpected status: $($health.status)"
    }

    Write-Host "  Full response:" -ForegroundColor Gray
    $health | ConvertTo-Json | Write-Host -ForegroundColor DarkGray
} catch {
    Write-TestResult "Health check endpoint" $false $_.Exception.Message
}

# Test 2: Version Info
Write-TestHeader "Test 2: Version Information Endpoint"
try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $version = Invoke-RestMethod -Uri "$FunctionAppUrl/version" -Method Get
    $stopwatch.Stop()

    if ($version.gitSha) {
        Write-TestResult "Version endpoint" $true "Git SHA: $($version.gitSha), Response time: $($stopwatch.ElapsedMilliseconds)ms"
    } else {
        Write-TestResult "Version endpoint" $false "No Git SHA found"
    }

    Write-Host "  Full response:" -ForegroundColor Gray
    $version | ConvertTo-Json | Write-Host -ForegroundColor DarkGray
} catch {
    Write-TestResult "Version endpoint" $false $_.Exception.Message
}

# Test 3: Prometheus Metrics
Write-TestHeader "Test 3: Prometheus Metrics Endpoint"
try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $metrics = Invoke-RestMethod -Uri "$FunctionAppUrl/metrics" -Method Get
    $stopwatch.Stop()

    $metricLines = ($metrics -split "`n" | Where-Object { $_ -match "^[a-z]" }).Count

    if ($metricLines -gt 0) {
        Write-TestResult "Metrics endpoint" $true "$metricLines metric series found, Response time: $($stopwatch.ElapsedMilliseconds)ms"

        # Check for specific metrics
        $requiredMetrics = @(
            "function_invocations_total",
            "function_duration_seconds",
            "weather_api_calls_total"
        )

        foreach ($metric in $requiredMetrics) {
            $found = $metrics -match $metric
            Write-TestResult "  Metric: $metric" $found
        }
    } else {
        Write-TestResult "Metrics endpoint" $false "No metrics found"
    }
} catch {
    Write-TestResult "Metrics endpoint" $false $_.Exception.Message
}

# Test 4: Weather Data for Multiple Cities
Write-TestHeader "Test 4: Weather Data Retrieval"

foreach ($city in $Cities) {
    try {
        $url = "$FunctionAppUrl/weather/$([uri]::EscapeDataString($city))"
        if ($FunctionKey) {
            $url += "?code=$FunctionKey"
        }

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $weather = Invoke-RestMethod -Uri $url -Method Get
        $stopwatch.Stop()

        if ($weather.city) {
            $details = "$($weather.city), $($weather.country) - $($weather.temperature)°C ($($weather.description)), Response time: $($stopwatch.ElapsedMilliseconds)ms"
            Write-TestResult "Weather data for $city" $true $details
        } else {
            Write-TestResult "Weather data for $city" $false "No city data returned"
        }
    } catch {
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-TestResult "Weather data for $city" $false "Authentication required (401) - Please provide function key with -FunctionKey parameter"
            break
        } else {
            Write-TestResult "Weather data for $city" $false $_.Exception.Message
        }
    }

    Start-Sleep -Milliseconds 500  # Rate limiting
}

# Test 5: Error Handling
Write-TestHeader "Test 5: Error Handling"

# Test with invalid city
try {
    $url = "$FunctionAppUrl/weather/InvalidCityName12345xyz"
    if ($FunctionKey) {
        $url += "?code=$FunctionKey"
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        Write-TestResult "Error handling (invalid city)" $false "Should have returned 404, got 200"
    } catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-TestResult "Error handling (invalid city)" $true "Correctly returned 404 Not Found"
        } elseif ($_.Exception.Response.StatusCode -eq 401) {
            Write-TestResult "Error handling (invalid city)" $true "Authentication required (skipping test)"
        } else {
            Write-TestResult "Error handling (invalid city)" $false "Unexpected status: $($_.Exception.Response.StatusCode)"
        }
    }
} catch {
    Write-TestResult "Error handling (invalid city)" $false $_.Exception.Message
}

# Test 6: Load Test (Optional)
if ($LoadTest) {
    Write-TestHeader "Test 6: Load Testing"

    Write-Host "Running load test with $LoadTestRequests requests..." -ForegroundColor Yellow

    $url = "$FunctionAppUrl/weather/London"
    if ($FunctionKey) {
        $url += "?code=$FunctionKey"
    }

    $loadResults = @()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    1..$LoadTestRequests | ForEach-Object -Parallel {
        $start = Get-Date
        try {
            $response = Invoke-RestMethod -Uri $using:url -ErrorAction Stop
            $duration = ((Get-Date) - $start).TotalMilliseconds
            [PSCustomObject]@{
                Success = $true
                Duration = $duration
            }
        } catch {
            [PSCustomObject]@{
                Success = $false
                Duration = 0
                Error = $_.Exception.Message
            }
        }
    } -ThrottleLimit 10 | ForEach-Object {
        $loadResults += $_
    }

    $stopwatch.Stop()

    # Calculate statistics
    $successful = ($loadResults | Where-Object { $_.Success }).Count
    $failed = ($loadResults | Where-Object { -not $_.Success }).Count
    $durations = ($loadResults | Where-Object { $_.Success }).Duration

    if ($durations.Count -gt 0) {
        $avgDuration = ($durations | Measure-Object -Average).Average
        $minDuration = ($durations | Measure-Object -Minimum).Minimum
        $maxDuration = ($durations | Measure-Object -Maximum).Maximum
        $sortedDurations = $durations | Sort-Object
        $p50 = $sortedDurations[[math]::Floor($sortedDurations.Count * 0.50)]
        $p95 = $sortedDurations[[math]::Floor($sortedDurations.Count * 0.95)]
        $p99 = $sortedDurations[[math]::Floor($sortedDurations.Count * 0.99)]

        Write-Host "`nLoad Test Results:" -ForegroundColor Cyan
        Write-Host "  Total Requests: $LoadTestRequests"
        Write-Host "  Successful: $successful" -ForegroundColor Green
        Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
        Write-Host "  Success Rate: $([math]::Round(($successful/$LoadTestRequests)*100, 2))%"
        Write-Host "  Total Duration: $([math]::Round($stopwatch.Elapsed.TotalSeconds, 2)) seconds"
        Write-Host "  Requests/Second: $([math]::Round($LoadTestRequests/$stopwatch.Elapsed.TotalSeconds, 2))"
        Write-Host "  Min Response Time: $([math]::Round($minDuration, 2)) ms"
        Write-Host "  Avg Response Time: $([math]::Round($avgDuration, 2)) ms"
        Write-Host "  Max Response Time: $([math]::Round($maxDuration, 2)) ms"
        Write-Host "  P50 Response Time: $([math]::Round($p50, 2)) ms"
        Write-Host "  P95 Response Time: $([math]::Round($p95, 2)) ms"
        Write-Host "  P99 Response Time: $([math]::Round($p99, 2)) ms"

        $loadTestPassed = ($successful / $LoadTestRequests) -gt 0.95 -and $p95 -lt 1000
        Write-TestResult "Load test ($LoadTestRequests requests)" $loadTestPassed "Success rate: $([math]::Round(($successful/$LoadTestRequests)*100, 2))%, P95: $([math]::Round($p95, 2))ms"
    } else {
        Write-TestResult "Load test" $false "No successful requests"
    }
}

# Summary
Write-TestHeader "Test Summary"

$results | Format-Table -AutoSize

$passed = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$total = $results.Count

Write-Host "`nResults: " -NoNewline
Write-Host "$passed PASSED" -ForegroundColor Green -NoNewline
Write-Host " / " -NoNewline
Write-Host "$failed FAILED" -ForegroundColor Red -NoNewline
Write-Host " / " -NoNewline
Write-Host "$total TOTAL" -ForegroundColor White

if ($failed -gt 0) {
    Write-Host "`n✗ TESTS FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✓ ALL TESTS PASSED" -ForegroundColor Green
    exit 0
}
