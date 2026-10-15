import Foundation

nonisolated struct RemoteTestMessageRepository: TestMessageRepository {
    private let client: any HTTPClient

    init(client: any HTTPClient = URLSessionHTTPClient()) {
        self.client = client
    }

    func send(message: String) async throws -> String {
        let url = URL(string: "https://httpbin.org/post")!
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(MessagePayload(message: message))
        let response: EchoResponse = try await client.decodedResponse(for: request)
        guard response.json.message == message else { throw AppError.invalidResponse }
        return response.json.message
    }
}

nonisolated private struct MessagePayload: Codable, Sendable {
    let message: String
}

nonisolated private struct EchoResponse: Decodable, Sendable {
    let json: MessagePayload
}
