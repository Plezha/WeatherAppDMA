import Foundation

nonisolated struct OpenMeteoForecast: Decodable, Sendable {
    let timezone: String
    let current: Current
    let hourly: Hourly?
    let daily: Daily?

    struct Current: Decodable, Sendable {
        let temperature: Double
        let apparentTemperature: Double
        let humidity: Int
        let windSpeed: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case humidity = "relative_humidity_2m"
            case windSpeed = "wind_speed_10m"
            case weatherCode = "weather_code"
        }
    }

    struct Hourly: Decodable, Sendable {
        let time: [Double]
        let temperature: [Double]
        let weatherCode: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    struct Daily: Decodable, Sendable {
        let time: [Double]
        let minTemperature: [Double]
        let maxTemperature: [Double]
        let weatherCode: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case minTemperature = "temperature_2m_min"
            case maxTemperature = "temperature_2m_max"
            case weatherCode = "weather_code"
        }
    }

    func weather(city: String) throws -> WeatherDTO {
        guard let hourly, let daily,
              !hourly.time.isEmpty, !daily.time.isEmpty,
              hourly.time.count == hourly.temperature.count,
              hourly.time.count == hourly.weatherCode.count,
              daily.time.count == daily.minTemperature.count,
              daily.time.count == daily.maxTemperature.count,
              daily.time.count == daily.weatherCode.count else {
            throw AppError.invalidResponse
        }
        let condition = Self.condition(for: current.weatherCode)
        return WeatherDTO(
            city: city,
            timezone: timezone,
            current: CurrentWeatherDTO(
                temperatureC: current.temperature,
                feelsLikeC: current.apparentTemperature,
                humidity: current.humidity,
                windMS: current.windSpeed,
                condition: condition.rawValue,
                description: condition.displayName
            ),
            hourly: hourly.time.indices.map { index in
                HourlyDTO(
                    time: Date(timeIntervalSince1970: hourly.time[index]),
                    temperatureC: hourly.temperature[index],
                    condition: Self.condition(for: hourly.weatherCode[index]).rawValue
                )
            },
            daily: daily.time.indices.map { index in
                DailyDTO(
                    date: Date(timeIntervalSince1970: daily.time[index]),
                    minC: daily.minTemperature[index],
                    maxC: daily.maxTemperature[index],
                    condition: Self.condition(for: daily.weatherCode[index]).rawValue
                )
            }
        )
    }

    static func condition(for code: Int) -> WeatherCondition {
        switch code {
        case 0, 1: return .clear
        case 2: return .partlyCloudy
        case 3: return .cloudy
        case 45, 48: return .fog
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return .rain
        case 71, 73, 75, 77, 85, 86: return .snow
        case 95, 96, 97, 99: return .thunderstorm
        default: return .unknown
        }
    }
}
