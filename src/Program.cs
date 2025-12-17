using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Prometheus;
using WeatherFunction.Services;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication()
    .ConfigureServices(services =>
    {
        // Application Insights
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();

        // HTTP Client for weather API
        services.AddHttpClient<IWeatherService, WeatherService>();

        // Prometheus metrics
        services.AddSingleton(Metrics.DefaultRegistry);

        // Configure logging
        services.Configure<LoggerFilterOptions>(options =>
        {
            // Remove default Application Insights filter to get all logs
            var defaultFilter = options.Rules.FirstOrDefault(rule =>
                rule.ProviderName == "Microsoft.Extensions.Logging.ApplicationInsights.ApplicationInsightsLoggerProvider");
            if (defaultFilter != null)
            {
                options.Rules.Remove(defaultFilter);
            }
        });
    })
    .ConfigureLogging(logging =>
    {
        // Add console logging for local development
        logging.AddConsole();

        // Configure minimum log levels
        logging.SetMinimumLevel(LogLevel.Information);
        logging.AddFilter("Microsoft.Azure.Functions", LogLevel.Information);
        logging.AddFilter("Host.Function", LogLevel.Information);
        logging.AddFilter("Host.Aggregator", LogLevel.Information);
    })
    .Build();

host.Run();
