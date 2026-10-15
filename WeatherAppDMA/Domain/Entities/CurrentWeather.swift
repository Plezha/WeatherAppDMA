import Foundation

nonisolated struct CurrentWeather: Equatable, Sendable {
    let temperatureC: Double
    let feelsLikeC: Double?
    let humidityPercent: Int
    let windMS: Double
    let condition: WeatherCondition
    let description: String
}
