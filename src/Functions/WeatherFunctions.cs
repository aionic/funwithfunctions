using System.Reflection;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Prometheus;
using WeatherFunction.Models;
using WeatherFunction.Services;

namespace WeatherFunction.Functions;

public class WeatherFunctions
{
    private readonly IWeatherService _weatherService;
    private readonly ILogger<WeatherFunctions> _logger;
    private readonly IConfiguration _configuration;

    // Prometheus metrics for function invocations
    private static readonly Counter FunctionInvocationsTotal = Metrics.CreateCounter(
        "function_invocations_total",
        "Total number of function invocations",
        new CounterConfiguration { LabelNames = new[] { "function", "status" } });

    private static readonly Histogram FunctionDuration = Metrics.CreateHistogram(
        "function_duration_seconds",
        "Duration of function execution in seconds",
        new HistogramConfiguration { LabelNames = new[] { "function" } });

    public WeatherFunctions(
        IWeatherService weatherService,
        ILogger<WeatherFunctions> logger,
        IConfiguration configuration)
    {
        _weatherService = weatherService;
        _logger = logger;
        _configuration = configuration;
    }

    [Function("GetWeather")]
    public async Task<IActionResult> GetWeather(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "weather/{city}")] HttpRequest req,
        string city,
        CancellationToken cancellationToken)
    {
        using (FunctionDuration.WithLabels("GetWeather").NewTimer())
        {
            _logger.LogInformation("Processing weather request for city: {City}", city);

            if (string.IsNullOrWhiteSpace(city))
            {
                FunctionInvocationsTotal.WithLabels("GetWeather", "bad_request").Inc();
                _logger.LogWarning("City parameter is required");
                return new BadRequestObjectResult(new { error = "City parameter is required" });
            }

            var weather = await _weatherService.GetWeatherAsync(city, cancellationToken);

            if (weather == null)
            {
                FunctionInvocationsTotal.WithLabels("GetWeather", "not_found").Inc();
                _logger.LogWarning("Weather data not found for city: {City}", city);
                return new NotFoundObjectResult(new { error = $"Weather data not found for city: {city}" });
            }

            FunctionInvocationsTotal.WithLabels("GetWeather", "success").Inc();
            _logger.LogInformation("Successfully processed weather request for city: {City}", city);

            return new OkObjectResult(weather);
        }
    }

    [Function("GetVersion")]
    public IActionResult GetVersion(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "version")] HttpRequest req)
    {
        using (FunctionDuration.WithLabels("GetVersion").NewTimer())
        {
            _logger.LogInformation("Processing version request");

            var assembly = Assembly.GetExecutingAssembly();
            var informationalVersion = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
            var version = assembly.GetName().Version?.ToString() ?? "1.0.0";

            var versionInfo = new VersionInfo
            {
                Version = version,
                GitSha = _configuration["BUILD_SOURCEVERSION"] ?? informationalVersion ?? "unknown",
                BuildDate = _configuration["BUILD_DATE"] ?? "unknown",
                Environment = _configuration["AZURE_FUNCTIONS_ENVIRONMENT"] ?? "Development"
            };

            FunctionInvocationsTotal.WithLabels("GetVersion", "success").Inc();
            _logger.LogInformation("Version info retrieved: {@VersionInfo}", versionInfo);

            return new OkObjectResult(versionInfo);
        }
    }

    [Function("GetMetrics")]
    public async Task<IActionResult> GetMetrics(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "metrics")] HttpRequest req)
    {
        using (FunctionDuration.WithLabels("GetMetrics").NewTimer())
        {
            _logger.LogInformation("Processing metrics request");

            try
            {
                var registry = Metrics.DefaultRegistry;
                await using var memoryStream = new MemoryStream();
                await registry.CollectAndExportAsTextAsync(memoryStream);

                var metricsText = System.Text.Encoding.UTF8.GetString(memoryStream.ToArray());

                FunctionInvocationsTotal.WithLabels("GetMetrics", "success").Inc();

                return new ContentResult
                {
                    Content = metricsText,
                    ContentType = "text/plain; version=0.0.4",
                    StatusCode = 200
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error generating metrics");
                FunctionInvocationsTotal.WithLabels("GetMetrics", "error").Inc();
                return new StatusCodeResult(500);
            }
        }
    }

    [Function("HealthCheck")]
    public IActionResult HealthCheck(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequest req)
    {
        _logger.LogInformation("Health check requested");

        return new OkObjectResult(new
        {
            status = "healthy",
            timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            version = _configuration["BUILD_SOURCEVERSION"] ?? "unknown"
        });
    }
}
