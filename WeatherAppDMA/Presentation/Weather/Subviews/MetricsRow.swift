import SwiftUI

struct MetricsRow: View {
    let current: CurrentWeather
    let temperatureUnit: TemperatureUnit
    let windUnit: WindUnit

    var body: some View {
        HStack(spacing: 12) {
            if let feelsLike = current.feelsLikeC {
                metric(
                    icon: "thermometer.medium",
                    title: "Ощущается",
                    value: UnitFormatter.temperature(celsius: feelsLike, unit: temperatureUnit)
                )
            }
            metric(
                icon: "humidity.fill",
                title: "Влажность",
                value: "\(current.humidityPercent)%"
            )
            metric(
                icon: "wind",
                title: "Ветер",
                value: UnitFormatter.wind(metersPerSecond: current.windMS, unit: windUnit)
            )
        }
        .padding(.horizontal)
    }

    private func metric(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
