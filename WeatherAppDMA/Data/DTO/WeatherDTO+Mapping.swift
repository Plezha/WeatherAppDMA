import Foundation

extension WeatherDTO {
    func toDomain() -> Weather {
        Weather(
            city: city,
            current: current.toDomain(),
            hourly: hourly.map { $0.toDomain() },
            daily: daily.map { $0.toDomain() },
            timezone: timezone,
            dailySummaryNote: dailySummaryNote
        )
    }
}

extension CurrentWeatherDTO {
    func toDomain() -> CurrentWeather {
        CurrentWeather(
            temperatureC: temperatureC,
            feelsLikeC: feelsLikeC,
            humidityPercent: humidity,
            windMS: windMS,
            condition: WeatherCondition(rawValue: condition) ?? .unknown,
            description: description
        )
    }
}

extension HourlyDTO {
    func toDomain() -> HourlyForecast {
        HourlyForecast(
            date: time,
            temperatureC: temperatureC,
            condition: WeatherCondition(rawValue: condition) ?? .unknown
        )
    }
}

extension DailyDTO {
    func toDomain() -> DailyForecast {
        DailyForecast(
            date: date,
            minC: minC,
            maxC: maxC,
            condition: WeatherCondition(rawValue: condition) ?? .unknown
        )
    }
}

extension CityDTO {
    func toDomain() -> CitySummary {
        CitySummary(
            name: name,
            currentTemperatureC: currentTemperatureC,
            condition: WeatherCondition(rawValue: condition) ?? .unknown,
            description: description
        )
    }
}
