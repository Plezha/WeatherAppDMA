import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    enum MessageState: Equatable {
        case idle
        case sending
        case sent(String)
        case failed(String)
    }

    @Published var isConfirmingWipe: Bool = false
    @Published private(set) var messageState: MessageState = .idle

    let store: PreferencesStore
    private let removeFavoritesUseCase: RemoveFavoriteUseCase
    private let sendTestMessageUseCase: SendTestMessageUseCase

    init(store: PreferencesStore, removeFavoritesUseCase: RemoveFavoriteUseCase, sendTestMessageUseCase: SendTestMessageUseCase) {
        self.store = store
        self.removeFavoritesUseCase = removeFavoritesUseCase
        self.sendTestMessageUseCase = sendTestMessageUseCase
    }

    var temperatureUnit: TemperatureUnit {
        get { store.preferences.temperatureUnit }
        set { store.setTemperatureUnit(newValue) }
    }

    var windUnit: WindUnit {
        get { store.preferences.windUnit }
        set { store.setWindUnit(newValue) }
    }

    func resetPreferences() {
        store.reset()
    }

    func wipeFavorites() async {
        try? await removeFavoritesUseCase.executeAll()
    }

    func sendTestMessage() async {
        guard messageState != .sending, !Task.isCancelled else { return }
        messageState = .sending
        do {
            let reply = try await sendTestMessageUseCase.execute()
            try Task.checkCancellation()
            messageState = .sent(reply)
        } catch {
            if Task.isCancelled || error is CancellationError {
                messageState = .idle
            } else {
                messageState = .failed(error.localizedDescription)
            }
        }
    }
}
