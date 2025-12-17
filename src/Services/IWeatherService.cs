using WeatherFunction.Models;

namespace WeatherFunction.Services;

public interface IWeatherService
{
    Task<WeatherResponse?> GetWeatherAsync(string city, CancellationToken cancellationToken = default);
}
