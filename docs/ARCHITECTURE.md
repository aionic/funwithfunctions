# Architecture Documentation

## Overview

This Azure Functions Weather API demonstrates a production-ready serverless architecture with comprehensive security, monitoring, and observability features. The solution leverages Azure Functions Flex Consumption plan with .NET 8 isolated worker model.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Internet / Client                               │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │ HTTPS
                                 ▼
                    ┌────────────────────────┐
                    │   Azure Function App   │
                    │  (Flex Consumption)    │
                    │   - .NET 8 Isolated    │
                    │   - Function Key Auth  │
                    │   - Version: Git SHA   │
                    └───────────┬────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
            ▼                   ▼                   ▼
    ┌───────────────┐   ┌──────────────┐   ┌──────────────┐
    │  App Insights │   │   Prometheus │   │ OpenWeather  │
    │   Telemetry   │   │    Metrics   │   │     API      │
    └───────────────┘   └──────────────┘   └──────────────┘
            │                   │
            │                   ▼
            │           ┌──────────────┐
            │           │   Managed    │
            │           │   Grafana    │
            │           └──────────────┘
            ▼
    ┌───────────────┐
    │ Log Analytics │
    │   Workspace   │
    └───────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                    Virtual Network (10.0.0.0/16)                         │
│                                                                           │
│  ┌────────────────────────┐      ┌─────────────────────────┐           │
│  │   Function Subnet      │      │ Private Endpoint Subnet │           │
│  │   (10.0.1.0/24)        │      │   (10.0.2.0/24)         │           │
│  │                        │      │                         │           │
│  │  ┌──────────────────┐ │      │  ┌────────────────────┐ │           │
│  │  │ Function App     │ │      │  │  Private Endpoint  │ │           │
│  │  │ VNet Integration │─┼──────┼─▶│  (Blob Storage)    │ │           │
│  │  └──────────────────┘ │      │  └────────────────────┘ │           │
│  │                        │      │  ┌────────────────────┐ │           │
│  │                        │      │  │  Private Endpoint  │ │           │
│  │                        │      │  │  (File Storage)    │ │           │
│  └────────────────────────┘      │  └────────────────────┘ │           │
│                                   └─────────────────────────┘           │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │              Storage Account (Public Access: Disabled)       │       │
│  │  - Blob Storage (deployment packages)                        │       │
│  │  - File Storage (function content share)                     │       │
│  │  - Managed Identity Authentication                           │       │
│  └─────────────────────────────────────────────────────────────┘       │
└───────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Azure Function App (Flex Consumption)

**Purpose**: Serverless HTTP API for weather data retrieval

**Key Features**:
- **.NET 8 Isolated Worker Model**: Latest runtime with improved performance
- **Flex Consumption Plan**: Automatic scaling with per-function scaling
- **VNet Integration**: Secure connectivity to private resources
- **Managed Identity**: Passwordless authentication
- **Git SHA Versioning**: Every deployment tagged with commit hash

**Configuration**:
- Instance Memory: 2048 MB
- Max Instances: 100
- Runtime: `dotnet-isolated/8.0`
- Linux-based

**Endpoints**:
- `GET /api/weather/{city}` - Weather data (Function key auth)
- `GET /api/version` - Version info (Anonymous)
- `GET /api/health` - Health check (Anonymous)
- `GET /api/metrics` - Prometheus metrics (Anonymous)

### 2. Virtual Network Architecture

**Purpose**: Network isolation and secure connectivity

**Subnets**:

1. **Function Subnet (10.0.1.0/24)**
   - Delegated to `Microsoft.Web/serverFarms`
   - Function app VNet integration
   - Outbound connectivity

2. **Private Endpoint Subnet (10.0.2.0/24)**
   - Private endpoints for storage
   - Private DNS zones
   - Network policies disabled for private endpoints

**Private DNS Zones**:
- `privatelink.blob.core.windows.net` - Blob storage
- `privatelink.file.core.windows.net` - File storage

### 3. Storage Account

**Purpose**: Function app deployment and content storage

**Security**:
- **Public Access**: Disabled
- **Network ACLs**: Deny by default, allow Azure services
- **TLS**: Minimum 1.2
- **Private Endpoints**: Blob and File services
- **Authentication**: Managed identity only

**Services**:
- **Blob Storage**: Deployment packages
- **File Storage**: Function content share (fallback)

### 4. Azure Key Vault

**Purpose**: Secure storage and management of secrets, keys, and certificates

**Security**:
- **RBAC Authorization**: Azure role-based access control enabled
- **Soft Delete**: 7-day retention for deleted secrets
- **Purge Protection**: Prevents permanent deletion during retention
- **Network Access**: Public access enabled (can be restricted with private endpoint)
- **Managed Identity Access**: Function app uses managed identity to access secrets

**Secrets**:
- **WeatherApiKey**: Weather API key stored securely
- Referenced by Function App using Key Vault references: `@Microsoft.KeyVault(SecretUri=...)`

**Role Assignments**:
- **Function App Managed Identity**: Key Vault Secrets User (read-only)
- **Deployment User**: Key Vault Secrets Officer (full management)

**Benefits**:
- Centralized secret management
- Automatic secret rotation support
- Audit logging of secret access
- Separation of secrets from application code
- No secrets in configuration files or source control

### 5. Monitoring Stack

#### Application Insights
**Purpose**: Application Performance Monitoring (APM)

**Capabilities**:
- Request telemetry and tracking
- Dependency tracking (HTTP calls)
- Exception logging and diagnostics
- Performance counters
- W3C distributed tracing
- Live metrics stream

**Configuration**:
- Sampling: 20 items/second
- Log Level: Information
- Workspace-based (Log Analytics)

#### Log Analytics Workspace
**Purpose**: Centralized log storage and analysis

**Features**:
- 30-day retention
- KQL query support
- Integration with App Insights
- Resource-based permissions

#### Prometheus Integration
**Purpose**: Custom metrics collection

**Metrics Exposed**:
```
# Function invocations
function_invocations_total{function="GetWeather",status="success"} 42
function_invocations_total{function="GetWeather",status="not_found"} 3

# Function duration
function_duration_seconds{function="GetWeather",quantile="0.5"} 0.125
function_duration_seconds{function="GetWeather",quantile="0.95"} 0.450

# Weather API calls
weather_api_calls_total{city="London",status="success"} 38
weather_api_calls_total{city="Paris",status="success"} 15

# Weather API duration
weather_api_duration_seconds{city="London",quantile="0.5"} 0.234
weather_api_duration_seconds{city="London",quantile="0.95"} 0.567
```

**Endpoint**: `/api/metrics` (Prometheus text format)

#### Azure Managed Grafana
**Purpose**: Metrics visualization and dashboarding

**Features**:
- Pre-configured Azure Monitor data source
- Azure Monitor Workspace integration
- Prometheus metric queries
- Built-in authentication (Azure AD)
- Monitoring Reader role assignment

**Recommended Dashboards**:
- Function performance metrics
- Weather API success rates
- Error tracking and alerting
- Request latency percentiles

### 5. Managed Identity

**Purpose**: Secure, passwordless authentication

**Type**: User-assigned managed identity

**Role Assignments**:
- **Storage Blob Data Contributor**: Read/write blob storage
- **Storage File Data Privileged Contributor**: Manage file shares
- **Key Vault Secrets User**: Read secrets from Key Vault

**Usage**:
- Function app authentication to storage
- Function app authentication to Key Vault
- No connection strings or keys in configuration
- Automatic token management

### 7. External Dependencies

#### Weather API Provider
**Purpose**: Weather data source

**Default Configuration**:
- **Provider**: OpenWeatherMap
- **Endpoint**: `https://api.openweathermap.org/data/2.5/weather`
- **Authentication**: API key

**Alternative Providers**:
- **WeatherAPI.com** (Recommended - no payment info required)
- **Open-Meteo** (Free, no API key)
- **7Timer!** (Free astronomy/weather)

**Configuration**:
- API Key: Stored in Azure Key Vault, referenced by Function App
- Base URL: Configurable via app settings
- Metrics: Call counts and duration tracked via Prometheus

## Security Architecture

### Defense in Depth

1. **Network Layer**
   - Private endpoints for storage
   - VNet integration for functions
   - No public storage access

2. **Identity Layer**
   - Managed identity authentication
   - Function key for API auth
   - Azure Key Vault for secrets
   - No secrets in code or configuration

3. **Transport Layer**
   - HTTPS only
   - TLS 1.2 minimum
   - Certificate pinning available

4. **Application Layer**
   - Input validation
   - Rate limiting (Azure Functions built-in)
   - Structured logging (no PII)

### Authentication Flow

```
Client Request
     ↓
Function Key Validation
     ↓
Function Execution
     ↓
Managed Identity Token Acquisition
     ↓
Storage Access (Private Endpoint)
     ↓
Weather API Call (HTTPS)
     ↓
Response
```

## Deployment Architecture

### CI/CD Pipeline

```
Developer Push
     ↓
GitHub Actions Trigger
     ↓
┌─────────────────────┐
│   Build Stage       │
│  - Restore deps     │
│  - Build with SHA   │
│  - Run tests        │
│  - Publish artifact │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│  Validate Stage     │
│  - Bicep lint       │
│  - Template validate│
│  - Security scan    │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│   Deploy Infra      │
│  - ARM deployment   │
│  - Tag with SHA     │
│  - Output variables │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│   Deploy App        │
│  - Function publish │
│  - Config update    │
│  - Health check     │
└─────────────────────┘
```

### Version Stamping

Every deployment includes:
- **Git SHA**: Full commit hash
- **Build Date**: UTC timestamp
- **Environment**: Target environment name

Accessible via `/api/version` endpoint

## Scalability

### Auto-Scaling Behavior

**Flex Consumption Plan Features**:
- Per-function scaling groups
- HTTP functions scale together
- Target-based scaling
- Rapid scale-out (< 1 second)
- Scale to zero when idle

**Scaling Metrics**:
- HTTP concurrency: 16 requests/instance (2048 MB)
- Max instances: 100 (configurable)
- Scale-out threshold: Based on HTTP queue length

**Performance Targets**:
- Cold start: < 1 second (pre-warmed instances)
- Request latency: P95 < 500ms
- Throughput: 1000+ requests/second

## Cost Optimization

### Resource Costs

1. **Function App (Flex Consumption)**
   - Pay per execution
   - No idle costs (scales to zero)
   - Memory-based pricing

2. **Storage Account**
   - Standard LRS tier
   - Minimal storage (< 1 GB typically)
   - Private endpoint: ~$7/month

3. **Monitoring**
   - Log Analytics: First 5 GB/month free
   - Application Insights: Included with Functions
   - Managed Grafana: Standard tier (~$230/month)

4. **Networking**
   - VNet: Free
   - Private endpoints: ~$7/endpoint/month
   - Data transfer: Standard rates

**Estimated Monthly Cost**: $250-$300 (primarily Grafana)

**Cost Reduction Options**:
- Use self-hosted Grafana
- Adjust Log Analytics retention
- Configure App Insights sampling
- Use Consumption plan (with limitations)

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Function Health**
   - Invocation count
   - Error rate
   - Duration (P50, P95, P99)
   - Cold starts

2. **Weather API**
   - Success rate
   - Latency
   - Rate limit tracking
   - Error responses

3. **Infrastructure**
   - Storage availability
   - VNet connectivity
   - Private endpoint health
   - Managed identity token acquisition

### Recommended Alerts

- Function error rate > 5%
- P95 latency > 1 second
- Weather API failures > 10%
- Storage unavailability
- Function app health check failures

## Disaster Recovery

### Backup Strategy

- **Code**: Git repository (GitHub)
- **Infrastructure**: Bicep templates in source control
- **Configuration**: App settings exported
- **Data**: Minimal stateful data (logs in Log Analytics)

### Recovery Procedures

**RTO (Recovery Time Objective)**: < 30 minutes
**RPO (Recovery Point Objective)**: Last committed code

**Recovery Steps**:
1. Re-run Bicep deployment (5-10 minutes)
2. Deploy latest function code (2-3 minutes)
3. Update DNS/traffic routing (5 minutes)
4. Verify health checks

## Future Enhancements

1. **Multi-Region Deployment**
   - Traffic Manager or Front Door
   - Geo-redundant storage
   - Regional failover

2. **Advanced Monitoring**
   - Custom Grafana dashboards
   - Alert rules in Azure Monitor
   - SLA tracking

3. **Security Enhancements**
   - Azure Key Vault integration
   - Microsoft Defender for Cloud
   - API Management gateway

4. **Performance**
   - Redis caching layer
   - CDN for static content
   - Always-ready instances

## References

- [Azure Functions Flex Consumption](https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan)
- [.NET Isolated Worker Model](https://learn.microsoft.com/en-us/azure/azure-functions/dotnet-isolated-process-guide)
- [Azure Private Link](https://learn.microsoft.com/en-us/azure/private-link/private-link-overview)
- [Managed Identities](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [Azure Managed Grafana](https://learn.microsoft.com/en-us/azure/managed-grafana/overview)
