import Foundation

nonisolated enum VisualCrossingConfiguration {
    static func loadAPIKey(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        if let key = nonEmpty(environment["VISUAL_CROSSING_API_KEY"]) { return key }
        guard let url = bundle.url(forResource: "WeatherAPIConfig.local", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Configuration.self, from: data) else { return nil }
        return nonEmpty(config.apiKey)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private struct Configuration: Decodable { let apiKey: String }
}
