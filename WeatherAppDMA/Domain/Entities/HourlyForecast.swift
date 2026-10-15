import Foundation

nonisolated struct HourlyForecast: Identifiable, Equatable, Sendable {
    let date: Date
    let temperatureC: Double
    let condition: WeatherCondition

    var id: Date { date }
}
