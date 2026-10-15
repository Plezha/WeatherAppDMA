import Foundation
import Testing
@testable import WeatherAppDMA

struct RemoteWeatherDataSourceTests {
    @Test
    func forecast_buildsRequestAndMapsWeather() async throws {
        let client = StubHTTPClient { request in
            let url = try #require(request.url)
            #expect(url.scheme == "https")
            #expect(url.host == "api.open-meteo.com")
            #expect(url.path == "/v1/forecast")
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
            let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value!) })
            #expect(values["latitude"] == "55.7522")
            #expect(values["longitude"] == "37.6156")
            #expect(values["wind_speed_unit"] == "ms")
            #expect(values["temperature_unit"] == "celsius")
            #expect(values["timeformat"] == "unixtime")
            #expect(values["timezone"] == "auto")
            #expect(values["forecast_days"] == "7")
            #expect(values["forecast_hours"] == "24")
            #expect(request.timeoutInterval == 20)
            return Self.response(Self.forecast, request: request)
        }
        let weather = try await RemoteWeatherDataSource(client: client).loadWeather(for: "  москва  ")
        #expect(weather.city == "Москва")
        #expect(weather.timezone == "Europe/Moscow")
        #expect(weather.current.temperatureC == 12.5)
        #expect(weather.current.feelsLikeC == 10.0)
        #expect(weather.current.humidity == 65)
        #expect(weather.current.windMS == 3.2)
        #expect(weather.current.condition == "rain")
        #expect(weather.hourly.count == 2)
        #expect(weather.hourly[0].time == Date(timeIntervalSince1970: 1_760_400_000))
        #expect(weather.hourly[1].condition == "snow")
        #expect(weather.daily[0].minC == 4)
        #expect(weather.daily[0].maxC == 14)
    }

    @Test
    func cities_usesOneBatchRequestAndPreservesCatalogueOrder() async throws {
        let client = StubHTTPClient { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(query.first { $0.name == "latitude" }?.value?.split(separator: ",").count == 12)
            #expect(!query.contains { $0.name == "hourly" || $0.name == "daily" })
            let rows = (0..<12).map { index in
                Self.currentOnly.replacingOccurrences(of: "12.5", with: String(index))
            }
            return Self.response("[" + rows.joined(separator: ",") + "]", request: request)
        }
        let cities = try await RemoteWeatherDataSource(client: client).loadCities()
        #expect(cities.count == 12)
        #expect(cities[0].name == "Санкт-Петербург")
        #expect(cities[1].name == "Москва")
        #expect(cities[11].name == "Иркутск")
        #expect(cities.map(\.currentTemperatureC) == (0..<12).map(Double.init))
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

    @Test(arguments: [429, 500])
    func nonSuccessHTTPStatus_isReportedBeforeDecoding(status: Int) async {
        let client = StubHTTPClient { request in
            Self.response("not JSON", status: status, request: request)
        }
        await #expect(throws: AppError.httpStatus(status)) {
            try await RemoteWeatherDataSource(client: client).loadWeather(for: "Москва")
        }
    }

    @Test(arguments: ["not JSON", currentOnly, forecast.replacingOccurrences(of: "[12.5, 11]", with: "[12.5]")])
    func malformedOrIncompleteForecast_isRejected(json: String) async {
        let client = StubHTTPClient { request in Self.response(json, request: request) }
        await #expect(throws: AppError.invalidResponse) {
            try await RemoteWeatherDataSource(client: client).loadWeather(for: "Москва")
        }
    }

    @Test
    func incompleteCityBatch_isRejected() async {
        let client = StubHTTPClient { request in Self.response("[]", request: request) }
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
    func weatherCodes_mapToKnownConditions() {
        let mapping: [Int: WeatherCondition] = [
            0: .clear, 2: .partlyCloudy, 3: .cloudy, 45: .fog, 51: .rain,
            71: .snow, 95: .thunderstorm, 97: .thunderstorm, 999: .unknown
        ]
        for (code, expected) in mapping {
            #expect(OpenMeteoForecast.condition(for: code) == expected)
        }
    }

    nonisolated private static func response(_ json: String, status: Int = 200, request: URLRequest) -> (Data, URLResponse) {
        (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    nonisolated private static let currentOnly = """
    {"timezone":"Europe/Moscow","current":{
      "temperature_2m":12.5,"apparent_temperature":10.0,"relative_humidity_2m":65,
      "wind_speed_10m":3.2,"weather_code":61}}
    """

    nonisolated private static let forecast = """
    {"timezone":"Europe/Moscow","current":{
      "temperature_2m":12.5,"apparent_temperature":10.0,"relative_humidity_2m":65,
      "wind_speed_10m":3.2,"weather_code":61},
     "hourly":{"time":[1760400000,1760403600],"temperature_2m":[12.5, 11],"weather_code":[61,71]},
     "daily":{"time":[1760389200],"temperature_2m_min":[4],"temperature_2m_max":[14],"weather_code":[3]}}
    """
}

private struct StubHTTPClient: HTTPClient {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}
