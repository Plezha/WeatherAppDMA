import Foundation

nonisolated struct DailyForecast: Identifiable, Equatable, Sendable {
    let date: Date
    let minC: Double
    let maxC: Double
    let condition: WeatherCondition

    var id: Date { date }
}
