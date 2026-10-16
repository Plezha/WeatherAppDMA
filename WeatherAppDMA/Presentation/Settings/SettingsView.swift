import SwiftUI

struct SettingsView: View {
    @StateObject private var vm: SettingsViewModel
    @ObservedObject private var store: PreferencesStore
    @Environment(\.dismiss) private var dismiss

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
