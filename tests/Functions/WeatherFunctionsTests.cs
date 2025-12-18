using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using WeatherFunction.Functions;
using Xunit;

namespace WeatherFunction.Tests.Functions;

public class WeatherFunctionsTests
{
    private readonly Mock<ILogger<WeatherFunctions>> _mockLogger;
    private readonly Mock<IConfiguration> _mockConfiguration;

    public WeatherFunctionsTests()
    {
        _mockLogger = new Mock<ILogger<WeatherFunctions>>();
        _mockConfiguration = new Mock<IConfiguration>();

        _mockConfiguration.Setup(x => x["BUILD_SOURCEVERSION"]).Returns("test-sha");
        _mockConfiguration.Setup(x => x["BUILD_DATE"]).Returns("test-date");
        _mockConfiguration.Setup(x => x["AZURE_FUNCTIONS_ENVIRONMENT"]).Returns("Test");
    }

    [Fact]
    public void GetVersion_ReturnsVersionInfo()
    {
        // Arrange
        var mockWeatherService = new Mock<WeatherFunction.Services.IWeatherService>();
        var function = new WeatherFunctions(mockWeatherService.Object, _mockLogger.Object, _mockConfiguration.Object);
        var mockRequest = new Mock<Microsoft.AspNetCore.Http.HttpRequest>();

        // Act
        var result = function.GetVersion(mockRequest.Object);

        // Assert
        result.Should().NotBeNull();
        result.Should().BeOfType<Microsoft.AspNetCore.Mvc.OkObjectResult>();

        var okResult = result as Microsoft.AspNetCore.Mvc.OkObjectResult;
        okResult.Should().NotBeNull();
        okResult!.StatusCode.Should().Be(200);
    }

    [Fact]
    public void HealthCheck_ReturnsHealthyStatus()
    {
        // Arrange
        var mockWeatherService = new Mock<WeatherFunction.Services.IWeatherService>();
        var function = new WeatherFunctions(mockWeatherService.Object, _mockLogger.Object, _mockConfiguration.Object);
        var mockRequest = new Mock<Microsoft.AspNetCore.Http.HttpRequest>();

        // Act
        var result = function.HealthCheck(mockRequest.Object);

        // Assert
        result.Should().NotBeNull();
        result.Should().BeOfType<Microsoft.AspNetCore.Mvc.OkObjectResult>();

        var okResult = result as Microsoft.AspNetCore.Mvc.OkObjectResult;
        okResult.Should().NotBeNull();
        okResult!.StatusCode.Should().Be(200);
    }

    [Fact]
    public async Task GetMetrics_ReturnsPrometheusMetrics()
    {
        // Arrange
        var mockWeatherService = new Mock<WeatherFunction.Services.IWeatherService>();
        var function = new WeatherFunctions(mockWeatherService.Object, _mockLogger.Object, _mockConfiguration.Object);
        var mockRequest = new Mock<Microsoft.AspNetCore.Http.HttpRequest>();

        // Act
        var result = await function.GetMetrics(mockRequest.Object);

        // Assert
        result.Should().NotBeNull();
        result.Should().BeOfType<Microsoft.AspNetCore.Mvc.ContentResult>();

        var contentResult = result as Microsoft.AspNetCore.Mvc.ContentResult;
        contentResult.Should().NotBeNull();
        contentResult!.ContentType.Should().Contain("text/plain");
        contentResult.StatusCode.Should().Be(200);
    }
}
