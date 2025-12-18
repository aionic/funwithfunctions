using FluentAssertions;
using WeatherFunction.Models;
using Xunit;

namespace WeatherFunction.Tests.Models;

public class WeatherModelsTests
{
    [Fact]
    public void WeatherResponse_CanBeCreated()
    {
        // Arrange & Act
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var weather = new WeatherResponse
        {
            City = "Seattle",
            Temperature = 15.5,
            Description = "Partly cloudy",
            Humidity = 75,
            WindSpeed = 10.5,
            Timestamp = timestamp
        };

        // Assert
        weather.City.Should().Be("Seattle");
        weather.Temperature.Should().Be(15.5);
        weather.Description.Should().Be("Partly cloudy");
        weather.Humidity.Should().Be(75);
        weather.WindSpeed.Should().Be(10.5);
        weather.Timestamp.Should().Be(timestamp);
    }

    [Fact]
    public void VersionInfo_CanBeCreated()
    {
        // Arrange & Act
        var version = new VersionInfo
        {
            Version = "1.0.0",
            GitSha = "abc123",
            BuildDate = "2024-01-01",
            Environment = "Production"
        };

        // Assert
        version.Version.Should().Be("1.0.0");
        version.GitSha.Should().Be("abc123");
        version.BuildDate.Should().Be("2024-01-01");
        version.Environment.Should().Be("Production");
    }
}
