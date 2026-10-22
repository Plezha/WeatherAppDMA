import Foundation
import SwiftData

@MainActor
enum CompositionRoot {
    // UI tests exercise requests, decoding, use cases, and persistence with a stub transport.
    private static let isUITesting: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        return false
        #endif
    }()

    private static let dataSource: WeatherDataSource = {
        #if DEBUG
        if isUITesting {
            let name = ProcessInfo.processInfo.environment["UI_TEST_NETWORK_SCENARIO"] ?? "success"
            guard let scenario = UITestHTTPClient.Scenario(rawValue: name) else {
                preconditionFailure("Unknown UI test network scenario: \(name)")
            }
            return RemoteWeatherDataSource(
                client: UITestHTTPClient(scenario: scenario),
                apiKey: "ui-test-key",
                now: { UITestHTTPClient.now }
            )
        }
        #endif
        return RemoteWeatherDataSource()
    }()
    private static let repository: WeatherRepository = DefaultWeatherRepository(dataSource: dataSource)

    static let modelContainer: ModelContainer = ModelContainerFactory.make(inMemory: isUITesting)

    private static let favoritesDataSource = SwiftDataFavoritesDataSource(context: modelContainer.mainContext)
    private static let favoritesRepository: FavoritesRepository = DefaultFavoritesRepository(dataSource: favoritesDataSource)

    private static let preferencesDataSource: UserDefaultsPreferencesDataSource = {
        guard isUITesting else { return UserDefaultsPreferencesDataSource() }
        let runID = ProcessInfo.processInfo.environment["UI_TEST_RUN_ID"] ?? UUID().uuidString
        let defaults = UserDefaults(suiteName: "WeatherAppDMA.UITests.\(runID)")!
        return UserDefaultsPreferencesDataSource(defaults: defaults)
    }()
    private static let preferencesRepository: PreferencesRepository = DefaultPreferencesRepository(dataSource: preferencesDataSource)

    static let preferencesStore: PreferencesStore = PreferencesStore(
        getUseCase: DefaultGetPreferencesUseCase(repository: preferencesRepository),
        updateUseCase: DefaultUpdatePreferencesUseCase(repository: preferencesRepository)
    )

    static func makeCitiesView() -> CitiesView {
        let viewModel = CitiesViewModel(
            getCities: DefaultGetCitiesUseCase(repository: repository),
            getFavorites: DefaultGetFavoritesUseCase(repository: favoritesRepository),
            addFavorite: DefaultAddFavoriteUseCase(repository: favoritesRepository),
            removeFavorite: DefaultRemoveFavoriteUseCase(repository: favoritesRepository)
        )
        return CitiesView(
            vm: viewModel,
            makeWeatherView: makeWeatherView(for:),
            makeFavoritesView: makeFavoritesView,
            makeSettingsView: makeSettingsView
        )
    }

    static func makeWeatherView(for city: String) -> WeatherView {
        let viewModel = WeatherViewModel(
            getWeather: DefaultGetWeatherForCityUseCase(repository: repository),
            initialCity: city,
            updatePreferences: DefaultUpdatePreferencesUseCase(repository: preferencesRepository)
        )
        return WeatherView(vm: viewModel)
    }

    static func makeFavoritesView() -> FavoritesView {
        let viewModel = FavoritesViewModel(
            getUseCase: DefaultGetFavoritesUseCase(repository: favoritesRepository),
            removeUseCase: DefaultRemoveFavoriteUseCase(repository: favoritesRepository),
            updateNoteUseCase: DefaultUpdateFavoriteNoteUseCase(repository: favoritesRepository),
            reorderUseCase: DefaultReorderFavoritesUseCase(repository: favoritesRepository)
        )
        return FavoritesView(vm: viewModel, makeWeatherView: makeWeatherView(for:))
    }

    static func makeSettingsView() -> SettingsView {
        let viewModel = SettingsViewModel(
            store: preferencesStore,
            removeFavoritesUseCase: DefaultRemoveFavoriteUseCase(repository: favoritesRepository)
        )
        return SettingsView(vm: viewModel)
    }
}
