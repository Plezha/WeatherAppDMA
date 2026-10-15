import Foundation

struct RemoteWeatherDataSource: WeatherDataSource {
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

        let response: OpenMeteoForecast = try await load(locations: [location], includeForecast: true)
        return try response.weather(city: location.name)
    }

    func loadCities() async throws -> [CityDTO] {
        // Open-Meteo accepts multiple coordinates in one request, in the same order.
        let responses: [OpenMeteoForecast] = try await load(locations: Self.cities, includeForecast: false)
        guard responses.count == Self.cities.count else { throw AppError.invalidResponse }
        return zip(Self.cities, responses).map { location, response in
            let condition = OpenMeteoForecast.condition(for: response.current.weatherCode)
            return CityDTO(
                name: location.name,
                currentTemperatureC: response.current.temperature,
                condition: condition.rawValue,
                description: condition.displayName
            )
        }
    }

    private func load<T: Decodable & Sendable>(locations: [Location], includeForecast: Bool) async throws -> T {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.open-meteo.com"
        components.path = "/v1/forecast"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: locations.map { String($0.latitude) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: locations.map { String($0.longitude) }.joined(separator: ",")),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: "ms"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime")
        ]
        if includeForecast {
            components.queryItems? += [
                URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
                URLQueryItem(name: "daily", value: "temperature_2m_min,temperature_2m_max,weather_code"),
                URLQueryItem(name: "forecast_days", value: "7"),
                URLQueryItem(name: "forecast_hours", value: "24")
            ]
        }
        guard let url = components.url else { throw AppError.invalidResponse }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try Task.checkCancellation()
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await client.data(for: request)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw AppError.networkUnavailable
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw AppError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AppError.httpStatus(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppError.invalidResponse
        }
    }

    private struct Location: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
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
