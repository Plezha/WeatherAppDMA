import Foundation

nonisolated struct Weather: Equatable, Sendable {
    let city: String
    let current: CurrentWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
    var timezone: String = "GMT"
}
