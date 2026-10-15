import SwiftUI

struct HourlyForecastStrip: View {
    let items: [HourlyForecast]
    let temperatureUnit: TemperatureUnit
    var timeZone: TimeZone = .current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Почасовой прогноз")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        VStack(spacing: 6) {
                            Text(item.date, format: Date.FormatStyle(
                                locale: Locale(identifier: "ru_RU"), timeZone: timeZone
                            ).hour(.twoDigits(amPM: .omitted)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: item.condition.sfSymbol)
                                .symbolRenderingMode(.multicolor)
                                .font(.title3)
                            Text(UnitFormatter.temperature(celsius: item.temperatureC, unit: temperatureUnit))
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .frame(width: 56)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

}
