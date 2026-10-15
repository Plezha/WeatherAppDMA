import Testing
import Foundation
@testable import WeatherAppDMA

@MainActor
struct WeatherViewModelTests {

    @Test
    func initialState_isIdle() {
        let vm = WeatherViewModel(getWeather: MockGetWeatherForCityUseCase(result: .success(Self.sampleWeather)), initialCity: nil)
        #expect(vm.state == .idle)
        #expect(vm.query == "")
    }

    @Test
    func search_emptyQuery_staysIdle() async {
        let vm = WeatherViewModel(getWeather: MockGetWeatherForCityUseCase(result: .success(Self.sampleWeather)), initialCity: nil)
        vm.query = "   "
        await vm.search()
        #expect(vm.state == .idle)
    }

    @Test
    func search_success_transitionsToLoaded() async {
        let vm = WeatherViewModel(getWeather: MockGetWeatherForCityUseCase(result: .success(Self.sampleWeather)), initialCity: nil)
        vm.query = "London"
        await vm.search()
        #expect(vm.state == .loaded(Self.sampleWeather))
    }

    @Test
    func search_cityNotFound_transitionsToNotFound() async {
        let vm = WeatherViewModel(getWeather: MockGetWeatherForCityUseCase(result: .failure(AppError.cityNotFound("Atlantis"))))
        vm.query = "Atlantis"
        await vm.search()
        #expect(vm.state == .notFound(city: "Atlantis"))
    }

    @Test
    func search_unknownError_transitionsToError() async {
        let vm = WeatherViewModel(getWeather: MockGetWeatherForCityUseCase(result: .failure(AppError.decodingFailed("boom"))))
        vm.query = "London"
        await vm.search()
        if case .error = vm.state {
            #expect(Bool(true))
        } else {
            Issue.record("Expected .error state, got \(vm.state)")
        }
    }

    @Test
    func callerCancellation_reachesLoadingTaskWithoutPublishingError() async {
        let useCase = SuspendedWeatherUseCase(weather: Self.sampleWeather)
        let vm = WeatherViewModel(getWeather: useCase)
        vm.query = "old"
        let caller = Task { await vm.search() }
        await useCase.waitUntilStarted()
        caller.cancel()
        await useCase.finishWithError()
        await caller.value
        #expect(await useCase.wasCancelled)
        #expect(vm.state == .loading)
    }

    @Test
    func cancelledOldRequest_cannotReplaceNewResultWithError() async {
        let useCase = SuspendedWeatherUseCase(weather: Self.sampleWeather)
        let vm = WeatherViewModel(getWeather: useCase)
        vm.query = "old"
        let old = Task { await vm.search() }
        await useCase.waitUntilStarted()
        vm.query = "new"
        await vm.search()
        await useCase.finishWithError()
        await old.value
        #expect(vm.state == .loaded(Self.sampleWeather))
    }

    // MARK: - Fixtures

    private static let sampleWeather = Weather(
        city: "London",
        current: CurrentWeather(
            temperatureC: 14.2,
            feelsLikeC: 13.0,
            humidityPercent: 65,
            windMS: 3.1,
            condition: .partlyCloudy,
            description: "Partly cloudy"
        ),
        hourly: [
            HourlyForecast(date: Date(timeIntervalSince1970: 0), temperatureC: 14, condition: .clear)
        ],
        daily: [
            DailyForecast(date: Date(timeIntervalSince1970: 0), minC: 10, maxC: 16, condition: .clear)
        ]
    )
}

private actor SuspendedWeatherUseCase: GetWeatherForCityUseCase {
    let weather: Weather
    private var pending: CheckedContinuation<Void, Never>?
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var started = false
    private(set) var wasCancelled = false

    init(weather: Weather) { self.weather = weather }

    func execute(city: String) async throws -> Weather {
        guard city == "old" else { return weather }
        await withCheckedContinuation { continuation in
            pending = continuation
            started = true
            startWaiter?.resume()
            startWaiter = nil
        }
        wasCancelled = Task.isCancelled
        throw AppError.httpStatus(500)
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func finishWithError() {
        pending?.resume()
        pending = nil
    }
}
