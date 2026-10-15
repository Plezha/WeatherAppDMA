import Foundation

nonisolated protocol TestMessageRepository: Sendable {
    func send(message: String) async throws -> String
}
