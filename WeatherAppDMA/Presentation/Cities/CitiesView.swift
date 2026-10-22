import SwiftUI

struct CitiesView: View {
    @StateObject private var vm: CitiesViewModel
    private let makeWeatherView: (String) -> WeatherView
    private let makeFavoritesView: () -> FavoritesView
    private let makeSettingsView: () -> SettingsView

    @State private var isSettingsPresented = false

    init(
        vm: CitiesViewModel,
        makeWeatherView: @escaping (String) -> WeatherView,
        makeFavoritesView: @escaping () -> FavoritesView,
        makeSettingsView: @escaping () -> SettingsView
    ) {
        _vm = StateObject(wrappedValue: vm)
        self.makeWeatherView = makeWeatherView
        self.makeFavoritesView = makeFavoritesView
        self.makeSettingsView = makeSettingsView
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Города")
                .searchable(
                    text: $vm.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Поиск города"
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            makeFavoritesView()
                        } label: {
                            Image(systemName: "star")
                        }
                        .accessibilityLabel("Избранное")
                        .accessibilityIdentifier("cities.favorites")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isSettingsPresented = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Настройки")
                        .accessibilityIdentifier("cities.settings")
                    }
                }
                .sheet(isPresented: $isSettingsPresented) {
                    makeSettingsView()
                }
                .task { await vm.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView("Загрузка…")
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            let cities = vm.filteredCities
            if cities.isEmpty {
                ContentUnavailableView(
                    "Ничего не найдено",
                    systemImage: "magnifyingglass",
                    description: Text("Попробуйте изменить запрос.")
                )
            } else {
                List(cities) { city in
                    NavigationLink {
                        makeWeatherView(city.name)
                    } label: {
                        CityRow(
                            city: city,
                            isFavorite: vm.isFavorite(city),
                            onToggleFavorite: {
                                Task { await vm.toggleFavorite(city) }
                            }
                        )
                    }
                    .accessibilityIdentifier("city.row.\(city.name)")
                }
                .listStyle(.plain)
                .refreshable { await vm.load() }
                .safeAreaInset(edge: .bottom) {
                    Link("Погода: Visual Crossing", destination: URL(string: "https://www.visualcrossing.com/weather-api/")!)
                        .font(.footnote)
                        .padding(.vertical, 8)
                }
            }

        case .error(let message):
            ContentUnavailableView {
                Label("Не удалось загрузить города", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
                    .accessibilityIdentifier("cities.error")
            } actions: {
                Button("Повторить") { Task { await vm.load() } }
                    .accessibilityIdentifier("cities.retry")
            }
        }
    }
}

private struct CityRow: View {
    let city: CitySummary
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: city.condition.sfSymbol)
                .symbolRenderingMode(.multicolor)
                .font(.title2)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .font(.headline)
                Text(city.condition.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(city.currentTemperatureC.rounded()))°")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFavorite ? "Удалить из избранного" : "Добавить в избранное")
            .accessibilityValue(isFavorite ? "В избранном" : "Не в избранном")
            .accessibilityIdentifier("favorite.toggle.\(city.name)")
        }
        .padding(.vertical, 4)
    }
}
