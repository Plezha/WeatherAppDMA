import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isConfirmingWipe: Bool = false

    let store: PreferencesStore
    private let removeFavoritesUseCase: RemoveFavoriteUseCase

    init(store: PreferencesStore, removeFavoritesUseCase: RemoveFavoriteUseCase) {
        self.store = store
        self.removeFavoritesUseCase = removeFavoritesUseCase
    }

    var temperatureUnit: TemperatureUnit {
        get { store.preferences.temperatureUnit }
        set { store.setTemperatureUnit(newValue) }
    }

    var windUnit: WindUnit {
        get { store.preferences.windUnit }
        set { store.setWindUnit(newValue) }
    }

    func resetPreferences() {
        store.reset()
    }

    func wipeFavorites() async {
        try? await removeFavoritesUseCase.executeAll()
    }
}
