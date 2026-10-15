import Foundation

nonisolated struct METNorwayForecast: Decodable, Sendable {
    let properties: Properties

    struct Properties: Decodable, Sendable {
        let timeseries: [Entry]
    }

    struct Entry: Decodable, Sendable {
        let time: Date
        let data: ForecastData

        var condition: WeatherCondition {
            let symbol = data.nextHour?.summary.symbolCode
                ?? data.nextSixHours?.summary.symbolCode
                ?? data.nextTwelveHours?.summary.symbolCode
            return METNorwayForecast.condition(for: symbol)
        }
    }

    struct ForecastData: Decodable, Sendable {
        let instant: Instant
        let nextHour: Period?
        let nextSixHours: Period?
        let nextTwelveHours: Period?

        enum CodingKeys: String, CodingKey {
            case instant
            case nextHour = "next_1_hours"
            case nextSixHours = "next_6_hours"
            case nextTwelveHours = "next_12_hours"
        }
    }

    struct Instant: Decodable, Sendable {
        let details: Details
    }

    struct Details: Decodable, Sendable {
        let temperature: Double
        let apparentTemperature: Double?
        let humidity: Double
        let windSpeed: Double

        enum CodingKeys: String, CodingKey {
            case temperature = "air_temperature"
            case apparentTemperature = "apparent_air_temperature"
            case humidity = "relative_humidity"
            case windSpeed = "wind_speed"
        }
    }

    struct Period: Decodable, Sendable {
        let summary: Summary
    }

    struct Summary: Decodable, Sendable {
        let symbolCode: String

        enum CodingKeys: String, CodingKey {
            case symbolCode = "symbol_code"
        }
    }

    func citySummary(name: String, now: Date = Date()) throws -> CityDTO {
        let entry = try currentEntry(now: now)
        return CityDTO(
            name: name, currentTemperatureC: entry.data.instant.details.temperature,
            condition: entry.condition.rawValue, description: entry.condition.displayName
        )
    }

    func weather(city: String, timezone: String, now: Date = Date()) throws -> WeatherDTO {
        guard let zone = TimeZone(identifier: timezone) else { throw AppError.invalidResponse }
        let current = try currentEntry(now: now)
        let details = current.data.instant.details
        guard (0...100).contains(details.humidity) else { throw AppError.invalidResponse }
        let entries = properties.timeseries.filter { $0.time >= current.time }.sorted { $0.time < $1.time }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let days = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.time) }
        let daily = days.keys.sorted().prefix(7).compactMap { date -> DailyDTO? in
            guard let points = days[date],
                  let min = points.map({ $0.data.instant.details.temperature }).min(),
                  let max = points.map({ $0.data.instant.details.temperature }).max() else { return nil }
            // Use the point closest to local noon for the day's representative icon.
            let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
            let representative = points.min { abs($0.time.timeIntervalSince(noon)) < abs($1.time.timeIntervalSince(noon)) }
            return DailyDTO(date: date, minC: min, maxC: max, condition: (representative?.condition ?? .unknown).rawValue)
        }
        return WeatherDTO(
            city: city, timezone: timezone,
            current: CurrentWeatherDTO(
                temperatureC: details.temperature, feelsLikeC: details.apparentTemperature,
                humidity: Int(details.humidity.rounded()), windMS: details.windSpeed,
                condition: current.condition.rawValue, description: current.condition.displayName
            ),
            hourly: entries.filter { $0.time < current.time.addingTimeInterval(24 * 3600) }.map {
                HourlyDTO(time: $0.time, temperatureC: $0.data.instant.details.temperature, condition: $0.condition.rawValue)
            },
            daily: daily,
            dailySummaryNote: "Приблизительный диапазон по точкам прогноза. Сегодня — на оставшуюся часть дня."
        )
    }

    private func currentEntry(now: Date) throws -> Entry {
        let entries = properties.timeseries.sorted { $0.time < $1.time }
        guard let entry = entries.last(where: { $0.time <= now }) ?? entries.first else {
            throw AppError.invalidResponse
        }
        return entry
    }

    static func condition(for symbol: String?) -> WeatherCondition {
        guard let symbol else { return .unknown }
        if symbol.contains("thunder") { return .thunderstorm }
        if symbol.contains("snow") || symbol.contains("sleet") { return .snow }
        if symbol.contains("rain") { return .rain }
        switch symbol.split(separator: "_").first {
        case "clearsky", "fair": return .clear
        case "partlycloudy": return .partlyCloudy
        case "cloudy": return .cloudy
        case "fog": return .fog
        default: return .unknown
        }
    }
}
