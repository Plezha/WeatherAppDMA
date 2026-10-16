import Foundation
import Testing
@testable import WeatherAppDMA

struct RemoteWeatherDataSourceTests {
    @Test
    func get_buildsForecastRequestAndMapsUnitsAndDates() async throws {
        let client = StubHTTPClient { request in
            let url = try #require(request.url)
            #expect(request.httpMethod == "GET")
            #expect(url.scheme == "https")
            #expect(url.host == "weather.visualcrossing.com")
            #expect(url.path == "/VisualCrossingWebServices/rest/services/timeline/55.7522,37.6156/next7days")
            let values = Self.parameters(URLComponents(url: url, resolvingAgainstBaseURL: false)!.percentEncodedQuery!)
            #expect(values["key"] == "test key+&=%")
            #expect(values["include"] == "days,hours,current")
            #expect(values["unitGroup"] == "metric")
            #expect(values["iconSet"] == "icons2")
            #expect(request.httpBody == nil)
            #expect(request.timeoutInterval == 20)
            return Self.response(Self.forecast, request: request)
        }
        let weather = try await Self.source(client).loadWeather(for: "  москва  ")
        #expect(weather.city == "Москва")
        #expect(weather.timezone == "Europe/Moscow")
        #expect(weather.current.temperatureC == 12.5)
        #expect(weather.current.feelsLikeC == 10)
        #expect(weather.current.humidity == 66)
        #expect(abs(weather.current.windMS - 3.2) < 0.001)
        #expect(weather.current.condition == "rain")
        #expect(weather.hourly.count == 2)
        #expect(weather.hourly[0].time == Self.now)
        #expect(weather.hourly[1].condition == "snow")
        #expect(weather.daily[0].minC == 4)
        #expect(weather.daily[0].maxC == 14)
        #expect(weather.daily[0].date == Date(timeIntervalSince1970: 1_760_389_200))
    }

    @Test
    func post_encodesBatchAndMatchesReorderedResponses() async throws {
        let client = StubHTTPClient { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/VisualCrossingWebServices/rest/services/timelinemulti")
            #expect(request.url?.query == nil)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8")
            let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
            let values = Self.parameters(body)
            #expect(values["key"] == "test key+&=%")
            #expect(body.contains("%2B"))
            #expect(body.contains("%7C"))
            #expect(values["include"] == "current")
            let coordinates = try #require(values["locations"]?.split(separator: "|").map(String.init))
            #expect(coordinates.count == 12)
            let rows = coordinates.enumerated().reversed().map { index, address in
                Self.currentOnly(address: address, temperature: index)
            }
            return Self.response("{\"locations\":[" + rows.joined(separator: ",") + "]}", request: request)
        }
        let cities = try await Self.source(client).loadCities()
        #expect(cities.count == 12)
        #expect(cities[0].name == "Санкт-Петербург")
        #expect(cities[1].name == "Москва")
        #expect(cities[11].name == "Иркутск")
        #expect(cities.map(\.currentTemperatureC) == (0..<12).map(Double.init))
    }

    @Test(arguments: ["{\"locations\":[]}", "invalid JSON"])
    func post_rejectsMissingCitiesAndMalformedJSON(json: String) async {
        let client = StubHTTPClient { request in Self.response(json, request: request) }
        await #expect(throws: AppError.invalidResponse) { try await Self.source(client).loadCities() }
    }

    @Test
    func post_rejectsDuplicateCities() async {
        let client = StubHTTPClient { request in
            let rows = Array(repeating: Self.currentOnly(address: "55.7522,37.6156", temperature: 1), count: 12)
            return Self.response("{\"locations\":[" + rows.joined(separator: ",") + "]}", request: request)
        }
        await #expect(throws: AppError.invalidResponse) { try await Self.source(client).loadCities() }
    }

    @Test(arguments: [false, true])
    func missingKey_doesNotMakeNetworkRequest(post: Bool) async {
        let client = StubHTTPClient { _ in
            Issue.record("Missing key must fail before sending a request")
            throw AppError.unknown
        }
        let source = RemoteWeatherDataSource(client: client, apiKey: nil)
        await #expect(throws: AppError.missingAPIKey) {
            if post { _ = try await source.loadCities() }
            else { _ = try await source.loadWeather(for: "Москва") }
        }
    }

    @Test(arguments: ["", "  ", "Атлантида"])
    func unsupportedCity_doesNotSendRequest(city: String) async {
        let client = StubHTTPClient { _ in
            Issue.record("Invalid city should not trigger a request")
            throw AppError.unknown
        }
        let expected: AppError = city.trimmingCharacters(in: .whitespaces).isEmpty ? .emptyQuery : .cityNotFound(city)
        await #expect(throws: expected) { try await Self.source(client).loadWeather(for: city) }
    }

    @Test(arguments: [401, 403, 429, 500], [false, true])
    func HTTPFailures_areReportedForBothMethods(status: Int, post: Bool) async {
        let client = StubHTTPClient { request in Self.response("not JSON", status: status, request: request) }
        let expected: AppError = status == 401 ? .invalidAPIKey : status == 429 ? .rateLimited : .httpStatus(status)
        await #expect(throws: expected) {
            if post { _ = try await Self.source(client).loadCities() }
            else { _ = try await Self.source(client).loadWeather(for: "Москва") }
        }
    }

    @Test(arguments: ["not JSON", "{}", forecast.replacingOccurrences(of: "\"days\":[", with: "\"other\":[")])
    func malformedOrIncompleteForecast_isRejected(json: String) async {
        let client = StubHTTPClient { request in Self.response(json, request: request) }
        await #expect(throws: AppError.invalidResponse) { try await Self.source(client).loadWeather(for: "Москва") }
    }

    @Test(arguments: [false, true])
    func transportErrors_andCancellationArePreserved(post: Bool) async {
        for code in [URLError.Code.notConnectedToInternet, .timedOut, .cancelled] {
            let client = StubHTTPClient { _ in throw URLError(code) }
            do {
                if post { _ = try await Self.source(client).loadCities() }
                else { _ = try await Self.source(client).loadWeather(for: "Москва") }
                Issue.record("Expected an error")
            } catch {
                if code == .cancelled { #expect(error is CancellationError) }
                else { #expect(error as? AppError == .networkUnavailable) }
            }
        }
    }

    @Test
    func nonHTTPResponse_isRejected() async {
        let client = StubHTTPClient { request in
            (Data(Self.forecast.utf8), URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
        }
        await #expect(throws: AppError.invalidResponse) { try await Self.source(client).loadWeather(for: "Москва") }
    }

    @Test
    func missingFeelsLike_andUnknownIconsRemainOptional() async throws {
        let json = Self.forecast.replacingOccurrences(of: "\"feelslike\":10,", with: "")
            .replacingOccurrences(of: "\"icon\":\"rain\"", with: "\"icon\":\"new-icon\"")
        let client = StubHTTPClient { request in Self.response(json, request: request) }
        let weather = try await Self.source(client).loadWeather(for: "Москва")
        #expect(weather.current.feelsLikeC == nil)
        #expect(weather.current.condition == "unknown")
    }

    @Test
    func localMock_remainsDecodable() async throws {
        let weather = try await LocalWeatherDataSource(loader: BundleJSONLoader()).loadWeather(for: "Москва")
        #expect(weather.current.feelsLikeC != nil)
    }

    @Test
    func environmentKey_takesPrecedenceAndIsTrimmed() {
        #expect(VisualCrossingConfiguration.loadAPIKey(environment: ["VISUAL_CROSSING_API_KEY": " test-key \n"]) == "test-key")
    }

    @Test
    func weatherIcons_mapToKnownConditions() {
        let mapping: [String: WeatherCondition] = [
            "clear-day": .clear, "clear-night": .clear, "partly-cloudy-day": .partlyCloudy,
            "cloudy": .cloudy, "fog": .fog, "showers-day": .rain, "rain": .rain,
            "snow": .snow, "rain-snow-showers-night": .snow, "thunder-rain": .thunderstorm,
            "thunder-showers-night": .thunderstorm, "new-icon": .unknown
        ]
        for (icon, expected) in mapping { #expect(VisualCrossingForecast.condition(for: icon) == expected) }
    }

    nonisolated private static let now = Date(timeIntervalSince1970: 1_760_400_000)
    nonisolated private static func source(_ client: any HTTPClient) -> RemoteWeatherDataSource {
        RemoteWeatherDataSource(client: client, apiKey: "test key+&=%", now: { Self.now })
    }
    nonisolated private static func parameters(_ encoded: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: encoded.split(separator: "&").map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return (String(parts[0]).removingPercentEncoding!, String(parts[1]).removingPercentEncoding!)
        })
    }
    nonisolated private static func response(_ json: String, status: Int = 200, request: URLRequest) -> (Data, URLResponse) {
        (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
    nonisolated private static func currentOnly(address: String, temperature: Int) -> String {
        """
        {"address":"\(address)","timezone":"Europe/Moscow","currentConditions":{
        "temp":\(temperature),"feelslike":10,"humidity":65,"windspeed":11.52,"icon":"rain"}}
        """
    }
    nonisolated private static let forecast = """
    {"address":"55.7522,37.6156","timezone":"Europe/Moscow","currentConditions":{
      "temp":12.5,"feelslike":10,"humidity":65.7,"windspeed":11.52,"icon":"rain"},
     "days":[{"datetimeEpoch":1760389200,"tempmin":4,"tempmax":14,"icon":"cloudy","hours":[
       {"datetimeEpoch":1760396400,"temp":13,"icon":"rain"},
       {"datetimeEpoch":1760400000,"temp":12.5,"icon":"rain"},
       {"datetimeEpoch":1760403600,"temp":11,"icon":"snow"},
       {"datetimeEpoch":1760486400,"temp":10,"icon":"clear-day"}]}]}
    """
}

private struct StubHTTPClient: HTTPClient {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { try await handler(request) }
}
