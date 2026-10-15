import Foundation
import Combine

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published private(set) var state: WeatherViewState = .idle
    @Published var query: String = ""

    let initialCity: String?
    private let getWeather: GetWeatherForCityUseCase
    private let updatePreferences: UpdatePreferencesUseCase?
    private var currentTask: Task<Void, Never>?

    init(
        getWeather: GetWeatherForCityUseCase,
        initialCity: String? = nil,
        updatePreferences: UpdatePreferencesUseCase? = nil
    ) {
        self.getWeather = getWeather
        self.initialCity = initialCity
        self.updatePreferences = updatePreferences
        if let city = initialCity {
            self.query = city
        }
    }

    func loadInitial() async {
        guard let city = initialCity else { return }
        await fetch(city: city)
    }

    func search() async {
        await fetch(city: query)
    }

    private func fetch(city: String) async {
        currentTask?.cancel()
        let task = Task { [getWeather, updatePreferences] in
            guard !Task.isCancelled else { return }
            let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                self.state = .idle
                return
            }
            self.state = .loading
            do {
                let weather = try await getWeather.execute(city: trimmed)
                try Task.checkCancellation()
                self.state = .loaded(weather)
                updatePreferences?.setLastOpenedCity(weather.city)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                switch error {
                case AppError.cityNotFound(let city):
                    self.state = .notFound(city: city)
                case AppError.emptyQuery:
                    self.state = .idle
                default:
                    let message = (error as? LocalizedError)?.errorDescription ?? "Что-то пошло не так."
                    self.state = .error(message: message)
                }
            }
        }
        currentTask = task
        // Task {} is unstructured: forward cancellation from SwiftUI's .task.
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
