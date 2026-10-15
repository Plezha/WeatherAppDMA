import Foundation

nonisolated enum WeatherCondition: String, Codable, Sendable, CaseIterable {
    case clear
    case partlyCloudy
    case cloudy
    case rain
    case thunderstorm
    case snow
    case fog
    case unknown

    var sfSymbol: String {
        switch self {
        case .clear:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .rain:         return "cloud.rain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snow:         return "cloud.snow.fill"
        case .fog:          return "cloud.fog.fill"
        case .unknown:      return "questionmark.circle"
        }
    }

    var displayName: String {
        switch self {
        case .clear:        return "Ясно"
        case .partlyCloudy: return "Переменная облачность"
        case .cloudy:       return "Облачно"
        case .rain:         return "Дождь"
        case .thunderstorm: return "Гроза"
        case .snow:         return "Снег"
        case .fog:          return "Туман"
        case .unknown:      return "Неизвестно"
        }
    }
}
