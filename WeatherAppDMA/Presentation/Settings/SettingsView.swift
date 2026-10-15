import SwiftUI

struct SettingsView: View {
    @StateObject private var vm: SettingsViewModel
    @ObservedObject private var store: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var messageRequestID = 0

    init(vm: SettingsViewModel) {
        _vm = StateObject(wrappedValue: vm)
        _store = ObservedObject(wrappedValue: vm.store)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Единицы измерения") {
                    Picker("Температура", selection: Binding(
                        get: { store.preferences.temperatureUnit },
                        set: { store.setTemperatureUnit($0) }
                    )) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }

                    Picker("Ветер", selection: Binding(
                        get: { store.preferences.windUnit },
                        set: { store.setWindUnit($0) }
                    )) {
                        ForEach(WindUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }

                Section("Сессия") {
                    if let city = store.preferences.lastOpenedCity {
                        LabeledContent("Последний город", value: city)
                        Button("Забыть последний город", role: .destructive) {
                            store.setLastOpenedCity(nil)
                        }
                    } else {
                        LabeledContent("Последний город", value: "—")
                    }
                }

                Section {
                    Button("Отправить тестовое сообщение") { messageRequestID += 1 }
                        .disabled(vm.messageState == .sending)
                    switch vm.messageState {
                    case .idle:
                        EmptyView()
                    case .sending:
                        ProgressView("Отправка…")
                    case .sent(let reply):
                        Label("Сервер вернул: \(reply)", systemImage: "checkmark.circle")
                            .font(.callout)
                    case .failed(let message):
                        Text(message)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Проверка связи")
                } footer: {
                    Text("Учебный сервис httpbin.org вернёт фиксированное сообщение. Настройки и избранные города не отправляются.")
                }

                Section("Данные") {
                    Button("Удалить всё избранное", role: .destructive) {
                        vm.isConfirmingWipe = true
                    }
                    Button("Сбросить настройки", role: .destructive) {
                        vm.resetPreferences()
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: messageRequestID) {
                guard messageRequestID > 0 else { return }
                await vm.sendTestMessage()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .confirmationDialog(
                "Удалить все избранные города?",
                isPresented: $vm.isConfirmingWipe,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    Task { await vm.wipeFavorites() }
                }
                Button("Отмена", role: .cancel) {}
            }
        }
    }
}
