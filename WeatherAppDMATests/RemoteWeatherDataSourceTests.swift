import Foundation
import Testing
@testable import WeatherAppDMA

struct RemoteWeatherDataSourceTests {
    @Test
    func forecast_buildsIdentifiedCacheableRequestAndMapsWeather() async throws {
        let client = StubHTTPClient { request in
            let url = try #require(request.url)
            #expect(url.scheme == "https")
            #expect(request.httpMethod == "GET")
            #expect(url.host == "api.met.no")
            #expect(url.path == "/weatherapi/locationforecast/2.0/complete")
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
            let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value!) })
            #expect(values == ["lat": "55.7522", "lon": "37.6156"])
            #expect(request.value(forHTTPHeaderField: "User-Agent") == "WeatherAppDMA/1.0 (https://github.com/v1lezz/WeatherAppDMA)")
            #expect(request.cachePolicy == .useProtocolCachePolicy)
            #expect(request.timeoutInterval == 20)
            return Self.response(Self.forecast, request: request)
        }
        let weather = try await RemoteWeatherDataSource(client: client).loadWeather(for: "  москва  ")
        #expect(weather.city == "Москва")
        #expect(weather.timezone == "Europe/Moscow")
        #expect(weather.current.temperatureC == 12.5)
        #expect(weather.current.feelsLikeC == 10.0)
        #expect(weather.current.humidity == 66)
        #expect(weather.current.windMS == 3.2)
        #expect(weather.current.condition == "rain")
        #expect(weather.hourly.count == 3)
        #expect(weather.hourly[0].time == ISO8601DateFormatter().date(from: "2099-10-15T20:00:00Z"))
        #expect(weather.hourly[1].condition == "snow")
        #expect(weather.daily[1].minC == 4)
        #expect(weather.daily[1].maxC == 11)
    }

    @Test
    func cities_limitsConcurrencyAndPreservesCatalogueOrder() async throws {
        let recorder = RequestRecorder()
        let client = StubHTTPClient { request in
            await recorder.begin(request)
            await Task.yield()
            await recorder.end()
            return Self.response(Self.forecast, request: request)
        }
        let cities = try await RemoteWeatherDataSource(client: client).loadCities()
        #expect(cities.count == 12)
        #expect(cities[0].name == "Санкт-Петербург")
        #expect(cities[1].name == "Москва")
        #expect(cities[11].name == "Иркутск")
        #expect(await recorder.requests.count == 12)
        #expect(await recorder.maxActive <= 3)
    }

    @Test
    func forecast_excludesPastAndGroupsDaysInCityTimezone() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let forecast = try decoder.decode(METNorwayForecast.self, from: Data(Self.forecast.utf8))
        let now = try #require(ISO8601DateFormatter().date(from: "2099-10-15T21:30:00Z"))
        let weather = try forecast.weather(city: "Москва", timezone: "Europe/Moscow", now: now)
        #expect(weather.current.temperatureC == 11)
        #expect(weather.current.feelsLikeC == nil)
        #expect(weather.hourly.count == 2)
        #expect(weather.daily.count == 1)
        #expect(weather.daily[0].date == ISO8601DateFormatter().date(from: "2099-10-15T21:00:00Z"))
        #expect(weather.dailySummaryNote != nil)
    }

    @Test
    func localMock_remainsDecodable() async throws {
        let weather = try await LocalWeatherDataSource(loader: BundleJSONLoader()).loadWeather(for: "Москва")
        #expect(weather.current.feelsLikeC != nil)
        #expect(weather.dailySummaryNote == nil)
    }

    @Test(arguments: ["", "  ", "Атлантида"])
    func unsupportedCity_doesNotSendRequest(city: String) async {
        let client = StubHTTPClient { _ in
            Issue.record("Invalid city should not trigger a request")
            throw AppError.unknown
        }
        let expected: AppError = city.trimmingCharacters(in: .whitespaces).isEmpty
            ? .emptyQuery : .cityNotFound(city)
        await #expect(throws: expected) {
            try await RemoteWeatherDataSource(client: client).loadWeather(for: city)
        }
    }

    @Test(arguments: [403, 429, 500])
    func nonSuccessHTTPStatus_isReportedBeforeDecoding(status: Int) async {
        let client = StubHTTPClient { request in
            Self.response("not JSON", status: status, request: request)
        }
        await #expect(throws: AppError.httpStatus(status)) {
            try await RemoteWeatherDataSource(client: client).loadWeather(for: "Москва")
        }
    }

    @Test(arguments: ["not JSON", emptyForecast, forecast.replacingOccurrences(of: "2099-10-15T20:00:00Z", with: "invalid")])
    func malformedOrEmptyForecast_isRejected(json: String) async {
        let client = StubHTTPClient { request in Self.response(json, request: request) }
        await #expect(throws: AppError.invalidResponse) {
            try await RemoteWeatherDataSource(client: client).loadWeather(for: "Москва")
        }
    }

    @Test
    func emptyCityForecast_isRejected() async {
        let client = StubHTTPClient { request in Self.response(Self.emptyForecast, request: request) }
        await #expect(throws: AppError.invalidResponse) {
            try await RemoteWeatherDataSource(client: client).loadCities()
        }
    }

    @Test
    func nonHTTPResponse_isRejected() async {
        let client = StubHTTPClient { request in
            (Data(Self.forecast.utf8), URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
        }
        await #expect(throws: AppError.invalidResponse) {
            try await RemoteWeatherDataSource(client: client).loadWeather(for: "Москва")
        }
    }

    @Test
    func offlineError_hasUserFacingMessage() async {
        let client = StubHTTPClient { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: AppError.networkUnavailable) {
            try await RemoteWeatherDataSource(client: client).loadWeather(for: "Москва")
        }
    }

    @Test
    func URLSessionCancellation_remainsCancellation() async {
        let client = StubHTTPClient { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) {
            try await RemoteWeatherDataSource(client: client).loadWeather(for: "Москва")
        }
    }

    @Test
    func weatherSymbols_mapToKnownConditions() {
        let mapping: [String: WeatherCondition] = [
            "clearsky_day": .clear, "fair_night": .clear, "partlycloudy_polartwilight": .partlyCloudy,
            "cloudy": .cloudy, "fog": .fog, "lightrainshowers_day": .rain,
            "heavysnow": .snow, "sleetshowers_night": .snow, "rainandthunder": .thunderstorm,
            "snowshowersandthunder_day": .thunderstorm, "new-symbol": .unknown
        ]
        for (symbol, expected) in mapping {
            #expect(METNorwayForecast.condition(for: symbol) == expected)
        }
        #expect(METNorwayForecast.condition(for: nil) == .unknown)
    }

    nonisolated private static func response(_ json: String, status: Int = 200, request: URLRequest) -> (Data, URLResponse) {
        (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    nonisolated private static let emptyForecast = #"{"properties":{"timeseries":[]}}"#

    nonisolated private static let forecast = """
    {"properties":{"timeseries":[
      {"time":"2099-10-15T20:00:00Z","data":{
        "instant":{"details":{"air_temperature":12.5,"apparent_air_temperature":10,"relative_humidity":65.7,"wind_speed":3.2}},
        "next_1_hours":{"summary":{"symbol_code":"rain"}}}},
      {"time":"2099-10-15T21:00:00Z","data":{
        "instant":{"details":{"air_temperature":11,"relative_humidity":65,"wind_speed":3.2}},
        "next_6_hours":{"summary":{"symbol_code":"snow"}}}},
      {"time":"2099-10-15T22:00:00Z","data":{
        "instant":{"details":{"air_temperature":4,"relative_humidity":65,"wind_speed":3.2}}}}
    ]}}
    """

}

private struct StubHTTPClient: HTTPClient {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}

private actor RequestRecorder {
    private(set) var requests: [URLRequest] = []
    private var active = 0
    private(set) var maxActive = 0

    func begin(_ request: URLRequest) {
        requests.append(request)
        active += 1
        maxActive = max(maxActive, active)
    }

    func end() { active -= 1 }
}
