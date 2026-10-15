import Foundation

nonisolated struct WeatherFileDTO: Sendable {
    let cities: [WeatherDTO]
}

nonisolated struct CityDTO: Sendable, Equatable {
    let name: String
    let currentTemperatureC: Double
    let condition: String
    let description: String
}

nonisolated struct WeatherDTO: Sendable {
    let city: String
    let timezone: String
    let current: CurrentWeatherDTO
    let hourly: [HourlyDTO]
    let daily: [DailyDTO]
    var dailySummaryNote: String? = nil
}

nonisolated struct CurrentWeatherDTO: Sendable {
    let temperatureC: Double
    let feelsLikeC: Double?
    let humidity: Int
    let windMS: Double
    let condition: String
    let description: String
}

nonisolated struct HourlyDTO: Sendable {
    let time: Date
    let temperatureC: Double
    let condition: String
}

nonisolated struct DailyDTO: Sendable {
    let date: Date
    let minC: Double
    let maxC: Double
    let condition: String
}

nonisolated extension WeatherFileDTO: Decodable {}
nonisolated extension WeatherDTO: Decodable {}
nonisolated extension CurrentWeatherDTO: Decodable {}
nonisolated extension HourlyDTO: Decodable {}
nonisolated extension DailyDTO: Decodable {}
