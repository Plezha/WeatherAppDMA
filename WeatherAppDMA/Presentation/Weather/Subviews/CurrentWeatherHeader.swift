import SwiftUI

struct CurrentWeatherHeader: View {
    let city: String
    let weather: CurrentWeather
    let temperatureUnit: TemperatureUnit

    var body: some View {
        VStack(spacing: 8) {
            Text(city)
                .font(.title)
                .fontWeight(.semibold)

            Image(systemName: weather.condition.sfSymbol)
                .renderingMode(.original)
                .font(.system(size: 72))
                .symbolRenderingMode(.multicolor)
                .padding(.vertical, 8)

            let displayValue = temperatureUnit.convert(fromCelsius: weather.temperatureC)
            HStack(alignment: .top, spacing: 2) {
                Text(Self.temperatureFormatter.string(from: NSNumber(value: displayValue)) ?? "—")
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .accessibilityIdentifier("weather.temperature")
                Text(temperatureUnit.displayName)
                    .font(.system(size: 32, weight: .light, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .accessibilityIdentifier("weather.temperatureUnit")
            }

            Text(weather.description)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private static let temperatureFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}
