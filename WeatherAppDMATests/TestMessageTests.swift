import Foundation
import Testing
@testable import WeatherAppDMA

struct TestMessageRepositoryTests {
    @Test
    func post_encodesJSONAndParsesEcho() async throws {
        let client = MessageHTTPClient { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://httpbin.org/post")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let body = try #require(request.httpBody)
            let object = try JSONDecoder().decode([String: String].self, from: body)
            #expect(object == ["message": "WeatherAppDMA connectivity test"])
            return Self.response(#"{"json":{"message":"WeatherAppDMA connectivity test"}}"#, request: request)
        }
        let useCase = DefaultSendTestMessageUseCase(repository: RemoteTestMessageRepository(client: client))
        #expect(try await useCase.execute() == "WeatherAppDMA connectivity test")
    }

    @Test(arguments: ["invalid JSON", "{}", #"{"json":null}"#, #"{"json":{"message":"different"}}"#])
    func invalidEcho_isRejected(json: String) async {
        let client = MessageHTTPClient { request in Self.response(json, request: request) }
        await #expect(throws: AppError.invalidResponse) {
            try await RemoteTestMessageRepository(client: client).send(message: "test")
        }
    }

    @Test
    func serverError_isReported() async {
        let client = MessageHTTPClient { request in Self.response("server error", status: 503, request: request) }
        await #expect(throws: AppError.httpStatus(503)) {
            try await RemoteTestMessageRepository(client: client).send(message: "test")
        }
    }

    @Test
    func timeout_isReportedAsNetworkError() async {
        let client = MessageHTTPClient { _ in throw URLError(.timedOut) }
        await #expect(throws: AppError.networkUnavailable) {
            try await RemoteTestMessageRepository(client: client).send(message: "test")
        }
    }

    @Test
    func cancelledPost_doesNotBecomeNetworkError() async {
        let client = MessageHTTPClient { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) {
            try await RemoteTestMessageRepository(client: client).send(message: "test")
        }
    }

    nonisolated private static func response(_ json: String, status: Int = 200, request: URLRequest) -> (Data, URLResponse) {
        (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor
struct SettingsMessageTests {
    @Test
    func success_displaysReturnedMessage() async {
        let vm = makeViewModel(result: .success("echoed message"))
        await vm.sendTestMessage()
        #expect(vm.messageState == .sent("echoed message"))
    }

    @Test
    func failure_displaysErrorAndAllowsRetry() async {
        let vm = makeViewModel(result: .failure(AppError.httpStatus(503)))
        await vm.sendTestMessage()
        #expect(vm.messageState == .failed(AppError.httpStatus(503).localizedDescription))
        #expect(vm.messageState != .sending)
    }

    @Test
    func cancellation_returnsToIdle() async {
        let vm = makeViewModel(result: .failure(CancellationError()))
        await vm.sendTestMessage()
        #expect(vm.messageState == .idle)
    }

    private func makeViewModel(result: Result<String, Error>) -> SettingsViewModel {
        let preferences = StubPreferencesRepository()
        return SettingsViewModel(
            store: PreferencesStore(
                getUseCase: DefaultGetPreferencesUseCase(repository: preferences),
                updateUseCase: DefaultUpdatePreferencesUseCase(repository: preferences)
            ),
            removeFavoritesUseCase: DefaultRemoveFavoriteUseCase(repository: MockFavoritesRepository()),
            sendTestMessageUseCase: StubSendMessage(result: result)
        )
    }
}

private struct MessageHTTPClient: HTTPClient {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { try await handler(request) }
}

private struct StubSendMessage: SendTestMessageUseCase {
    let result: Result<String, Error>
    func execute() async throws -> String { try result.get() }
}

private struct StubPreferencesRepository: PreferencesRepository {
    func get() -> UserPreferences { .default }
    func update(_ preferences: UserPreferences) {}
    func setTemperatureUnit(_ unit: TemperatureUnit) {}
    func setWindUnit(_ unit: WindUnit) {}
    func setLastOpenedCity(_ city: String?) {}
    func reset() {}
}
