import Foundation
import Combine

@MainActor
final class CitiesViewModel: ObservableObject {
    @Published private(set) var state: CitiesViewState = .loading
    @Published private(set) var favorites: [FavoriteCity] = []
    @Published var query: String = ""

    private let getCities: GetCitiesUseCase
    private let getFavorites: GetFavoritesUseCase
    private let addFavorite: AddFavoriteUseCase
    private let removeFavorite: RemoveFavoriteUseCase

    init(
        getCities: GetCitiesUseCase,
        getFavorites: GetFavoritesUseCase,
        addFavorite: AddFavoriteUseCase,
        removeFavorite: RemoveFavoriteUseCase
    ) {
        self.getCities = getCities
        self.getFavorites = getFavorites
        self.addFavorite = addFavorite
        self.removeFavorite = removeFavorite
    }

    var filteredCities: [CitySummary] {
        guard case .loaded(let cities) = state else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return cities }
        return cities.filter {
            $0.name.range(of: trimmed, options: .caseInsensitive) != nil
        }
    }

    func isFavorite(_ city: CitySummary) -> Bool {
        favorites.contains { $0.cityName.lowercased() == city.name.lowercased() }
    }

    func load() async {
        // Keep the refreshable List mounted while its network request is running.
        switch state {
        case .loaded: break
        default: state = .loading
        }
        do {
            async let citiesTask = getCities.execute()
            async let favoritesTask = getFavorites.execute()
            let (cities, favs) = try await (citiesTask, favoritesTask)
            try Task.checkCancellation()
            favorites = favs
            state = .loaded(cities)
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            let message = (error as? LocalizedError)?.errorDescription ?? "Что-то пошло не так."
            state = .error(message: message)
        }
    }

    func refreshFavorites() async {
        if let favs = try? await getFavorites.execute() {
            favorites = favs
        }
    }

    func toggleFavorite(_ city: CitySummary) async {
        do {
            if let existing = favorites.first(where: { $0.cityName.lowercased() == city.name.lowercased() }) {
                try await removeFavorite.execute(id: existing.id)
            } else {
                _ = try await addFavorite.execute(cityName: city.name, note: nil)
            }
            await refreshFavorites()
        } catch {
            // tolerate; UI stays consistent on next load
        }
    }
}
