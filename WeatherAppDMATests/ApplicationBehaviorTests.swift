import Foundation
import Testing
@testable import WeatherAppDMA

@MainActor
struct ApplicationBehaviorTests {
    @Test
    func citySearch_ignoresCaseAndWhitespaceAndRestoresListWhenCleared() async {
        let cities = ["Москва", "Казань", "Санкт-Петербург"].map {
            CitySummary(name: $0, currentTemperatureC: 10, condition: .clear, description: "Ясно")
        }
        let favorites = MockFavoritesRepository()
        let vm = CitiesViewModel(
            getCities: StubGetCities(cities: cities),
            getFavorites: DefaultGetFavoritesUseCase(repository: favorites),
            addFavorite: DefaultAddFavoriteUseCase(repository: favorites),
            removeFavorite: DefaultRemoveFavoriteUseCase(repository: favorites)
        )
        await vm.load()

        vm.query = "  мОсК  \n"
        #expect(vm.filteredCities.map(\.name) == ["Москва"])
        vm.query = "Несуществующий город"
        #expect(vm.filteredCities.isEmpty)
        vm.query = "  \n"
        #expect(vm.filteredCities == cities)
    }

    @Test
    func favoriteReorderFailure_isShownAndReloadRestoresPersistedOrder() async throws {
        let repository = MockFavoritesRepository()
        let moscow = try await repository.add(cityName: "Москва", note: nil)
        let kazan = try await repository.add(cityName: "Казань", note: nil)
        let failure = AppError.persistenceFailed("Недостаточно места")
        let vm = FavoritesViewModel(
            getUseCase: DefaultGetFavoritesUseCase(repository: repository),
            removeUseCase: DefaultRemoveFavoriteUseCase(repository: repository),
            updateNoteUseCase: DefaultUpdateFavoriteNoteUseCase(repository: repository),
            reorderUseCase: FailingReorder(error: failure)
        )
        await vm.load()
        await vm.move(from: IndexSet(integer: 0), to: 2)

        #expect(vm.state == .error(message: failure.localizedDescription))
        await vm.load()
        #expect(vm.state == .loaded([moscow, kazan]))
    }
}

private struct StubGetCities: GetCitiesUseCase {
    let cities: [CitySummary]
    func execute() async throws -> [CitySummary] { cities }
}

private struct FailingReorder: ReorderFavoritesUseCase {
    let error: AppError
    func execute(ids: [UUID]) async throws { throw error }
}
