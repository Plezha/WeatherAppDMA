import Foundation

nonisolated struct RemoteWeatherDataSource: WeatherDataSource {
    private let client: any HTTPClient

    init(client: any HTTPClient = URLSessionHTTPClient()) {
        self.client = client
    }

    func loadWeather(for city: String) async throws -> WeatherDTO {
        let name = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AppError.emptyQuery }
        guard let location = Self.cities.first(where: {
            $0.name.compare(name, options: .caseInsensitive) == .orderedSame
        }) else { throw AppError.cityNotFound(name) }

        let response = try await load(location: location)
        return try response.weather(city: location.name, timezone: location.timezone)
    }

    func loadCities() async throws -> [CityDTO] {
        // MET Norway serves one location per request. Limit concurrency and preserve UI order.
        let fetch: @Sendable (Int) async throws -> (Int, CityDTO) = { index in
            let location = Self.cities[index]
            let response = try await load(location: location)
            return (index, try response.citySummary(name: location.name))
        }
        return try await withThrowingTaskGroup(of: (Int, CityDTO).self) { group in
            var nextIndex = 0
            for _ in 0..<min(3, Self.cities.count) {
                let index = nextIndex
                group.addTask { try await fetch(index) }
                nextIndex += 1
            }
            var result: [(Int, CityDTO)] = []
            while let item = try await group.next() {
                result.append(item)
                if nextIndex < Self.cities.count {
                    let index = nextIndex
                    group.addTask { try await fetch(index) }
                    nextIndex += 1
                }
            }
            return result.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func load(location: Location) async throws -> METNorwayForecast {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.met.no"
        components.path = "/weatherapi/locationforecast/2.0/complete"
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(location.latitude)),
            URLQueryItem(name: "lon", value: String(location.longitude))
        ]
        guard let url = components.url else { throw AppError.invalidResponse }
        // URLSession honors Expires/Last-Modified through its standard HTTP cache.
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("WeatherAppDMA/1.0 (https://github.com/v1lezz/WeatherAppDMA)", forHTTPHeaderField: "User-Agent")
        return try await client.decodedResponse(for: request)
    }

    private struct Location: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
        let timezone: String
    }

    // The existing city catalogue stays fixed; only weather comes from the API.
    private static let cities: [Location] = [
        Location(name: "Санкт-Петербург", latitude: 59.9386, longitude: 30.3141, timezone: "Europe/Moscow"),
        Location(name: "Москва", latitude: 55.7522, longitude: 37.6156, timezone: "Europe/Moscow"),
        Location(name: "Казань", latitude: 55.7887, longitude: 49.1221, timezone: "Europe/Moscow"),
        Location(name: "Екатеринбург", latitude: 56.8519, longitude: 60.6122, timezone: "Asia/Yekaterinburg"),
        Location(name: "Новосибирск", latitude: 55.0415, longitude: 82.9346, timezone: "Asia/Novosibirsk"),
        Location(name: "Сочи", latitude: 43.5992, longitude: 39.7257, timezone: "Europe/Moscow"),
        Location(name: "Владивосток", latitude: 43.1056, longitude: 131.8735, timezone: "Asia/Vladivostok"),
        Location(name: "Калининград", latitude: 54.7065, longitude: 20.5110, timezone: "Europe/Kaliningrad"),
        Location(name: "Мурманск", latitude: 68.9792, longitude: 33.0925, timezone: "Europe/Moscow"),
        Location(name: "Нижний Новгород", latitude: 56.3287, longitude: 44.0020, timezone: "Europe/Moscow"),
        Location(name: "Ростов-на-Дону", latitude: 47.2314, longitude: 39.7233, timezone: "Europe/Moscow"),
        Location(name: "Иркутск", latitude: 52.2978, longitude: 104.2964, timezone: "Asia/Irkutsk")
    ]
}
