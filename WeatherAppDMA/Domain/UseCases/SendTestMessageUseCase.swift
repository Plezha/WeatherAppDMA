import Foundation

nonisolated protocol SendTestMessageUseCase: Sendable {
    func execute() async throws -> String
}

nonisolated struct DefaultSendTestMessageUseCase: SendTestMessageUseCase {
    let repository: TestMessageRepository

    func execute() async throws -> String {
        try await repository.send(message: "WeatherAppDMA connectivity test")
    }
}
