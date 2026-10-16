import Foundation

nonisolated struct RemoteWeatherDataSource: WeatherDataSource {
    private let client: any HTTPClient
    private let apiKey: String?
    private let now: @Sendable () -> Date

    init(client: any HTTPClient = URLSessionHTTPClient(),
         apiKey: String? = VisualCrossingConfiguration.loadAPIKey(),
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.apiKey = apiKey
        self.now = now
    }

    func loadWeather(for city: String) async throws -> WeatherDTO {
        let name = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AppError.emptyQuery }
        guard let location = Self.cities.first(where: {
            $0.name.compare(name, options: .caseInsensitive) == .orderedSame
        }) else { throw AppError.cityNotFound(name) }

        let request = try makeRequest(path: "timeline/\(location.coordinates)/next7days", method: "GET",
                                      parameters: [("include", "days,hours,current")])
        let response: VisualCrossingForecast = try await client.decodedResponse(for: request)
        return try response.weather(city: location.name, now: now())
    }

    func loadCities() async throws -> [CityDTO] {
        let request = try makeRequest(path: "timelinemulti", method: "POST", parameters: [
            ("locations", Self.cities.map(\.coordinates).joined(separator: "|")),
            ("include", "current")
        ])
        let response: VisualCrossingLocations = try await client.decodedResponse(for: request)
        guard response.locations.count == Self.cities.count else { throw AppError.invalidResponse }
        // Match the original requested address instead of depending on response order.
        let byAddress = Dictionary(grouping: response.locations, by: \.address)
        return try Self.cities.map { location in
            guard let matches = byAddress[location.coordinates], matches.count == 1,
                  let forecast = matches.first else { throw AppError.invalidResponse }
            return forecast.citySummary(name: location.name)
        }
    }

    private func makeRequest(path: String, method: String, parameters: [(String, String)]) throws -> URLRequest {
        guard let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw AppError.missingAPIKey
        }
        let values = parameters + [("key", key), ("unitGroup", "metric"),
                                   ("contentType", "json"), ("iconSet", "icons2")]
        let encoded = Self.formEncoded(values)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "weather.visualcrossing.com"
        components.path = "/VisualCrossingWebServices/rest/services/" + path
        if method == "GET" { components.percentEncodedQuery = encoded }
        guard let url = components.url else { throw AppError.invalidResponse }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method == "POST" {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(encoded.utf8)
        }
        return request
    }

    private static func formEncoded(_ parameters: [(String, String)]) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return parameters.map { name, value in
            "\(name.addingPercentEncoding(withAllowedCharacters: allowed)!)=\(value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&")
    }

    private struct Location: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
        var coordinates: String { "\(latitude),\(longitude)" }
    }

    // The existing city catalogue stays fixed; only weather comes from the API.
    private static let cities: [Location] = [
        Location(name: "Санкт-Петербург", latitude: 59.9386, longitude: 30.3141),
        Location(name: "Москва", latitude: 55.7522, longitude: 37.6156),
        Location(name: "Казань", latitude: 55.7887, longitude: 49.1221),
        Location(name: "Екатеринбург", latitude: 56.8519, longitude: 60.6122),
        Location(name: "Новосибирск", latitude: 55.0415, longitude: 82.9346),
        Location(name: "Сочи", latitude: 43.5992, longitude: 39.7257),
        Location(name: "Владивосток", latitude: 43.1056, longitude: 131.8735),
        Location(name: "Калининград", latitude: 54.7065, longitude: 20.5110),
        Location(name: "Мурманск", latitude: 68.9792, longitude: 33.0925),
        Location(name: "Нижний Новгород", latitude: 56.3287, longitude: 44.0020),
        Location(name: "Ростов-на-Дону", latitude: 47.2314, longitude: 39.7233),
        Location(name: "Иркутск", latitude: 52.2978, longitude: 104.2964)
    ]
}
