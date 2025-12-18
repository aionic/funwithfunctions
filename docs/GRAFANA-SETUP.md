# Grafana Data Source Setup Guide

## Adding Function App Metrics to Grafana

### Option 1: Prometheus Data Source (Direct Scraping)

1. **Open Grafana**
   - Get URL from `grafana-config.json` or Azure Portal

2. **Add Data Source**
   - Navigate to: **Connections → Data sources → Add data source**
   - Select: **Prometheus**

3. **Configure**
   - **Name**: `Function App Metrics`
   - **URL**: `https://func-dev-svc2voxpoyhgo.azurewebsites.net`
   - **HTTP Method**: POST (default for Prometheus)
   - **Timeout**: 30 seconds
   - **Auth**: None (all auth options disabled)

4. **Custom HTTP Headers** (optional)
   - Add `X-Prometheus-Scrape-Path: /api/metrics` if needed

5. **Save & Test**
   - Click "Save & test" button
   - Should show "Successfully queried the Prometheus API"

### Option 2: Azure Monitor Workspace (Auto-configured)

The Azure Monitor Workspace data source should already be configured automatically with your Grafana instance.

## Troubleshooting

### 404 Error When Testing
- **Cause**: Using wrong URL format or data source type
- **Solution**:
  - Ensure URL is base domain only (no `/api/metrics` path)
  - Verify you selected "Prometheus" data source type

### Connection Timeout
- **Cause**: Function app may be cold starting
- **Solution**:
  - Hit the metrics endpoint directly first: `curl https://func-dev-svc2voxpoyhgo.azurewebsites.net/api/metrics`
  - Wait 10-15 seconds and try again

### 401 Unauthorized
- **Cause**: Auth is configured when it shouldn't be
- **Solution**: Disable all authentication options in Grafana data source config

## Available Metrics

Once configured, you'll have access to:

### Custom Function Metrics
- `function_invocations_total` - Counter of function calls by name and status
- `function_duration_seconds` - Histogram of function execution duration

### .NET Runtime Metrics
- `dotnet_collection_count_total` - GC collections
- `dotnet_total_memory_bytes` - Memory usage
- `process_cpu_seconds_total` - CPU usage
- `process_working_set_bytes` - Working set
- And many more .NET diagnostics metrics

### HTTP Metrics
- `system_net_http_http_client_active_requests` - Outbound HTTP requests
- `microsoft_aspnetcore_hosting_total_requests` - Incoming requests
- `microsoft_aspnetcore_server_kestrel_current_connections` - Active connections

## Example Queries

```promql
# Function invocation rate
rate(function_invocations_total[5m])

# P95 function duration
histogram_quantile(0.95, rate(function_duration_seconds_bucket[5m]))

# Memory usage
dotnet_total_memory_bytes / 1024 / 1024

# HTTP request rate
rate(microsoft_aspnetcore_hosting_total_requests[5m])
```
