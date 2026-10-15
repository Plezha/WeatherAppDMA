import SwiftUI

struct DailyForecastList: View {
    let items: [DailyForecast]
    let temperatureUnit: TemperatureUnit
    var timeZone: TimeZone = .current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Прогноз на 7 дней")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text(item.date, format: Date.FormatStyle(
                            locale: Locale(identifier: "ru_RU"), timeZone: timeZone
                        ).weekday(.abbreviated).day().month(.abbreviated))
                            .frame(width: 120, alignment: .leading)
                        Spacer()
                        Image(systemName: item.condition.sfSymbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.title3)
                        Spacer()
                        Text("\(UnitFormatter.temperature(celsius: item.minC, unit: temperatureUnit)) / \(UnitFormatter.temperature(celsius: item.maxC, unit: temperatureUnit))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    if index < items.count - 1 {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

}
