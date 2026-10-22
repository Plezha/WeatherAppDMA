#if DEBUG
import Foundation

/// Replaces only HTTP transport; the app still builds requests and decodes API JSON.
actor UITestHTTPClient: HTTPClient {
    enum Scenario: String {
        case success
        case retry
    }

    private enum Endpoint {
        case cities
        case forecast
    }

    // Keep the forecast's hourly timestamps valid regardless of the test run date.
    static let now = Date(timeIntervalSince1970: 1_760_400_000)

    private let scenario: Scenario
    private var failedEndpoints: Set<Endpoint> = []

    init(scenario: Scenario) {
        self.scenario = scenario
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        guard let url = request.url,
              url.scheme == "https", url.host == "weather.visualcrossing.com" else {
            throw URLError(.unsupportedURL)
        }

        let endpoint: Endpoint
        switch (request.httpMethod, url.path) {
        case ("POST", "/VisualCrossingWebServices/rest/services/timelinemulti"):
            endpoint = .cities
        case ("GET", "/VisualCrossingWebServices/rest/services/timeline/55.7522,37.6156/next7days"):
            endpoint = .forecast
        default:
            // Unexpected requests must fail instead of reaching the real network.
            throw URLError(.unsupportedURL)
        }

        if scenario == .retry, failedEndpoints.insert(endpoint).inserted {
            switch endpoint {
            case .cities:
                return (Data(), HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!)
            case .forecast:
                throw URLError(.timedOut)
            }
        }

        let json = endpoint == .cities ? Self.citiesJSON : Self.forecastJSON
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        return (Data(json.utf8), response)
    }

    // A fixed response catalogue, independent of the incoming POST form.
    private static let citiesJSON: String = {
        let addresses = [
            "59.9386,30.3141", "55.7522,37.6156", "55.7887,49.1221", "56.8519,60.6122",
            "55.0415,82.9346", "43.5992,39.7257", "43.1056,131.8735", "54.7065,20.511",
            "68.9792,33.0925", "56.3287,44.002", "47.2314,39.7233", "52.2978,104.2964"
        ]
        let locations = addresses.enumerated().map { index, address in
            """
            {"address":"\(address)","timezone":"Europe/Moscow","currentConditions":{
              "temp":\(10 + index),"humidity":65,"windspeed":11.52,"icon":"rain"}}
            """
        }
        return "{\"locations\":[" + locations.reversed().joined(separator: ",") + "]}"
    }()

    private static let forecastJSON = """
    {"address":"55.7522,37.6156","timezone":"Europe/Moscow","currentConditions":{
      "temp":12.5,"feelslike":10,"humidity":65.7,"windspeed":11.52,"icon":"rain"},
     "days":[{"datetimeEpoch":1760389200,"tempmin":4,"tempmax":14,"icon":"cloudy","hours":[
       {"datetimeEpoch":1760400000,"temp":12.5,"icon":"rain"},
       {"datetimeEpoch":1760403600,"temp":11,"icon":"snow"}]}]}
    """
}
#endif
