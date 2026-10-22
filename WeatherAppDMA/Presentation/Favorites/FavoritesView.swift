import SwiftUI

struct FavoritesView: View {
    @StateObject private var vm: FavoritesViewModel
    private let makeWeatherView: (String) -> WeatherView

    @State private var editingFavorite: FavoriteCity?

    init(vm: FavoritesViewModel, makeWeatherView: @escaping (String) -> WeatherView) {
        _vm = StateObject(wrappedValue: vm)
        self.makeWeatherView = makeWeatherView
    }

    var body: some View {
        content
            .navigationTitle("Избранное")
            .toolbar {
                if case .loaded = vm.state {
                    EditButton()
                }
            }
            .task { await vm.load() }
            .sheet(item: $editingFavorite) { favorite in
                EditNoteSheet(favorite: favorite) { newNote in
                    editingFavorite = nil
                    Task { await vm.updateNote(id: favorite.id, note: newNote) }
                } onCancel: {
                    editingFavorite = nil
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            ContentUnavailableView(
                "Избранного нет",
                systemImage: "star",
                description: Text("Добавьте город из списка, нажав на звезду.")
            )

        case .loaded(let items):
            List {
                ForEach(items) { favorite in
                    NavigationLink {
                        makeWeatherView(favorite.cityName)
                    } label: {
                        FavoriteRow(favorite: favorite)
                    }
                    .accessibilityIdentifier("favorite.row.\(favorite.cityName)")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await vm.delete(id: favorite.id) }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                        .accessibilityIdentifier("favorite.delete.\(favorite.cityName)")
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingFavorite = favorite
                        } label: {
                            Label("Заметка", systemImage: "square.and.pencil")
                        }
                        .tint(.blue)
                        .accessibilityIdentifier("favorite.editNote.\(favorite.cityName)")
                    }
                }
                .onMove { source, destination in
                    Task { await vm.move(from: source, to: destination) }
                }
            }
            .listStyle(.plain)

        case .error(let message):
            ContentUnavailableView(
                "Не удалось загрузить избранное",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }
}

private struct FavoriteRow: View {
    let favorite: FavoriteCity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text(favorite.cityName)
                    .font(.headline)
            }
            if let note = favorite.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EditNoteSheet: View {
    let favorite: FavoriteCity
    let onSave: (String?) -> Void
    let onCancel: () -> Void

    @State private var noteText: String

    init(favorite: FavoriteCity, onSave: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
        self.favorite = favorite
        self.onSave = onSave
        self.onCancel = onCancel
        _noteText = State(initialValue: favorite.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(favorite.cityName) {
                    TextField("Заметка", text: $noteText, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("favorite.noteText")
                }
            }
            .navigationTitle("Заметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed.isEmpty ? nil : trimmed)
                    }
                    .accessibilityIdentifier("favorite.saveNote")
                }
            }
        }
    }
}
