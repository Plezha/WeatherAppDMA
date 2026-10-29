import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @ObservedObject private var store: PreferencesStore
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _store = ObservedObject(wrappedValue: viewModel.store)
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
                    .accessibilityIdentifier("settings.temperatureUnit")

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
                        viewModel.isConfirmingWipe = true
                    }
                    Button("Сбросить настройки", role: .destructive) {
                        viewModel.resetPreferences()
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
            .confirmationDialog(
                "Удалить все избранные города?",
                isPresented: $viewModel.isConfirmingWipe,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    Task { await viewModel.wipeFavorites() }
                }
                Button("Отмена", role: .cancel) {}
            }
        }
    }
}
