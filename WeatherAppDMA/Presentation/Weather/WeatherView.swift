import SwiftUI

struct WeatherView: View {
    @StateObject private var vm: WeatherViewModel
    @EnvironmentObject private var preferences: PreferencesStore

    init(vm: WeatherViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        content
            .navigationTitle(vm.initialCity ?? "Погода")
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.loadInitial() }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle:
            ContentUnavailableView(
                "Выберите город",
                systemImage: "magnifyingglass",
                description: Text("Вернитесь к списку и выберите город.")
            )

        case .loading:
            ProgressView("Загрузка…")
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let weather):
            ScrollView {
                VStack(spacing: 20) {
                    CurrentWeatherHeader(
                        city: weather.city,
                        weather: weather.current,
                        temperatureUnit: preferences.preferences.temperatureUnit
                    )
                    MetricsRow(
                        current: weather.current,
                        temperatureUnit: preferences.preferences.temperatureUnit,
                        windUnit: preferences.preferences.windUnit
                    )
                    HourlyForecastStrip(
                        items: weather.hourly,
                        temperatureUnit: preferences.preferences.temperatureUnit,
                        timeZone: TimeZone(identifier: weather.timezone) ?? .gmt
                    )
                    DailyForecastList(
                        items: weather.daily,
                        temperatureUnit: preferences.preferences.temperatureUnit,
                        timeZone: TimeZone(identifier: weather.timezone) ?? .gmt,
                        note: weather.dailySummaryNote
                    )
                    Link("Погода: MET Norway · CC BY 4.0", destination: URL(string: "https://api.met.no/doc/License")!)
                        .font(.footnote)
                }
                .padding(.vertical)
            }

        case .notFound(let city):
            ContentUnavailableView(
                "Нет данных",
                systemImage: "cloud.slash",
                description: Text("Не удалось найти погоду для «\(city)».")
            )

        case .error(let message):
            ContentUnavailableView {
                Label("Что-то пошло не так", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Повторить") { Task { await vm.loadInitial() } }
            }
        }
    }
}
