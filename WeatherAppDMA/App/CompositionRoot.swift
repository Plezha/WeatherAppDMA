import Foundation
import SwiftData

@MainActor
enum CompositionRoot {
    private static let dataSource: WeatherDataSource = RemoteWeatherDataSource()
    private static let repository: WeatherRepository = DefaultWeatherRepository(dataSource: dataSource)

    static let modelContainer: ModelContainer = ModelContainerFactory.make()

    private static let favoritesDataSource = SwiftDataFavoritesDataSource(context: modelContainer.mainContext)
    private static let favoritesRepository: FavoritesRepository = DefaultFavoritesRepository(dataSource: favoritesDataSource)

    private static let preferencesDataSource = UserDefaultsPreferencesDataSource()
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
            removeFavoritesUseCase: DefaultRemoveFavoriteUseCase(repository: favoritesRepository),
            sendTestMessageUseCase: DefaultSendTestMessageUseCase(repository: RemoteTestMessageRepository())
        )
        return SettingsView(vm: viewModel)
    }
}
