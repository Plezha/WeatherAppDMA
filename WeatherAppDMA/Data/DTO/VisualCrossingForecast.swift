import Foundation

nonisolated struct VisualCrossingLocations: Decodable, Sendable {
    let locations: [VisualCrossingForecast]
}

nonisolated struct VisualCrossingForecast: Decodable, Sendable {
    let address: String
    let timezone: String
    let currentConditions: Current
    let days: [Day]?

    struct Current: Decodable, Sendable {
        let temp: Double
        let feelslike: Double?
        let humidity: Double
        let windspeed: Double
        let icon: String
    }

    struct Hour: Decodable, Sendable {
        let datetimeEpoch: Double
        let temp: Double
        let icon: String
    }

    struct Day: Decodable, Sendable {
        let datetimeEpoch: Double
        let tempmin: Double
        let tempmax: Double
        let icon: String
        let hours: [Hour]?
    }

    func citySummary(name: String) -> CityDTO {
        let condition = Self.condition(for: currentConditions.icon)
        return CityDTO(name: name, currentTemperatureC: currentConditions.temp,
                       condition: condition.rawValue, description: condition.displayName)
    }

    func weather(city: String, now: Date = Date()) throws -> WeatherDTO {
        guard let days, !days.isEmpty, TimeZone(identifier: timezone) != nil,
              (0...100).contains(currentConditions.humidity),
              days.allSatisfy({ $0.tempmin <= $0.tempmax }) else { throw AppError.invalidResponse }
        let sortedDays = days.sorted { $0.datetimeEpoch < $1.datetimeEpoch }
        let currentHour = floor(now.timeIntervalSince1970 / 3600) * 3600
        let allHours: [Hour] = sortedDays.flatMap { $0.hours ?? [] }
        let endHour = currentHour + 24 * 3600
        let upcomingHours = allHours.filter { $0.datetimeEpoch >= currentHour && $0.datetimeEpoch < endHour }
        let hours = upcomingHours.sorted { $0.datetimeEpoch < $1.datetimeEpoch }
        guard !hours.isEmpty else { throw AppError.invalidResponse }
        let condition = Self.condition(for: currentConditions.icon)
        return WeatherDTO(
            city: city, timezone: timezone,
            current: CurrentWeatherDTO(
                temperatureC: currentConditions.temp, feelsLikeC: currentConditions.feelslike,
                humidity: Int(currentConditions.humidity.rounded()), windMS: currentConditions.windspeed / 3.6,
                condition: condition.rawValue, description: condition.displayName
            ),
            hourly: hours.map {
                HourlyDTO(time: Date(timeIntervalSince1970: $0.datetimeEpoch), temperatureC: $0.temp,
                          condition: Self.condition(for: $0.icon).rawValue)
            },
            daily: sortedDays.prefix(7).map {
                DailyDTO(date: Date(timeIntervalSince1970: $0.datetimeEpoch), minC: $0.tempmin, maxC: $0.tempmax,
                         condition: Self.condition(for: $0.icon).rawValue)
            }
        )
    }

    static func condition(for icon: String) -> WeatherCondition {
        if icon.contains("thunder") { return .thunderstorm }
        if icon.contains("snow") || icon == "sleet" || icon == "ice" { return .snow }
        if icon.contains("rain") || icon.contains("showers") { return .rain }
        switch icon {
        case "clear-day", "clear-night": return .clear
        case "partly-cloudy-day", "partly-cloudy-night": return .partlyCloudy
        case "cloudy": return .cloudy
        case "fog": return .fog
        default: return .unknown
        }
    }
}
