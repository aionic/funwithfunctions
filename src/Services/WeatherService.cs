using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Prometheus;
using WeatherFunction.Models;

namespace WeatherFunction.Services;

public class WeatherService : IWeatherService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<WeatherService> _logger;

    // Prometheus metrics
    private static readonly Counter WeatherApiCallsTotal = Metrics.CreateCounter(
        "weather_api_calls_total",
        "Total number of weather API calls",
        new CounterConfiguration { LabelNames = new[] { "city", "status" } });

    private static readonly Histogram WeatherApiDuration = Metrics.CreateHistogram(
        "weather_api_duration_seconds",
        "Duration of weather API calls in seconds",
        new HistogramConfiguration { LabelNames = new[] { "city" } });

    public WeatherService(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<WeatherService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<WeatherResponse?> GetWeatherAsync(string city, CancellationToken cancellationToken = default)
    {
        var apiKey = _configuration["WeatherApiKey"];
        var baseUrl = _configuration["WeatherApiBaseUrl"] ?? "https://api.weatherapi.com/v1";

        if (string.IsNullOrEmpty(apiKey))
        {
            _logger.LogError("WeatherApiKey is not configured");
            WeatherApiCallsTotal.WithLabels(city, "error_no_key").Inc();
            return null;
        }

        using (WeatherApiDuration.WithLabels(city).NewTimer())
        {
            try
            {
                // WeatherAPI.com format: /current.json?key=<API_KEY>&q=<CITY>
                var url = $"{baseUrl}/current.json?key={apiKey}&q={Uri.EscapeDataString(city)}";

                _logger.LogInformation("Fetching weather data for city: {City} from WeatherAPI.com", city);

                var response = await _httpClient.GetAsync(url, cancellationToken);

                if (!response.IsSuccessStatusCode)
                {
                    var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                    _logger.LogWarning("Weather API returned status code: {StatusCode} for city: {City}. Error: {Error}",
                        response.StatusCode, city, errorContent);
                    WeatherApiCallsTotal.WithLabels(city, $"error_{(int)response.StatusCode}").Inc();
                    return null;
                }

                var content = await response.Content.ReadAsStringAsync(cancellationToken);
                var weatherData = JsonSerializer.Deserialize<WeatherApiComResponse>(content, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                if (weatherData?.Location == null || weatherData.Current == null)
                {
                    _logger.LogError("Failed to deserialize weather data for city: {City}", city);
                    WeatherApiCallsTotal.WithLabels(city, "error_deserialization").Inc();
                    return null;
                }

                WeatherApiCallsTotal.WithLabels(city, "success").Inc();
                _logger.LogInformation("Successfully retrieved weather data for city: {City}", city);

                return new WeatherResponse
                {
                    City = weatherData.Location.Name,
                    Country = weatherData.Location.Country,
                    Temperature = weatherData.Current.Temp_C,
                    FeelsLike = weatherData.Current.Feelslike_C,
                    Description = weatherData.Current.Condition?.Text,
                    Humidity = weatherData.Current.Humidity,
                    WindSpeed = weatherData.Current.Wind_Kph,
                    Timestamp = weatherData.Current.Last_Updated_Epoch
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching weather data for city: {City}", city);
                WeatherApiCallsTotal.WithLabels(city, "error_exception").Inc();
                return null;
            }
        }
    }
}
