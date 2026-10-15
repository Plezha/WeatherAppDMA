import Foundation

nonisolated struct CitySummary: Identifiable, Equatable, Sendable {
    let name: String
    let currentTemperatureC: Double
    let condition: WeatherCondition
    let description: String

    var id: String { name }
}
