#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct ModelManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = ModelManager.shared

    @State private var isImporterPresented = false
    @State private var importError: ModelManagerError?
    @State private var generalError: GeneralError?

    var body: some View {
        List {
            if manager.installed.isEmpty {
                emptyPlaceholder
            } else {
                Section("Установленные модели") {
                    ForEach(manager.installed) { model in
                        modelRow(model)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !model.isActive {
                                    Button(role: .destructive) { delete(model) } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }

            Section("Каталог") {
                HStack {
                    Text("Путь")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(manager.modelsDirectory.path)
                        .multilineTextAlignment(.trailing)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Модели ИИ")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Закрыть") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Импорт", systemImage: "square.and.arrow.down")
                }
            }
        }
        .refreshable { manager.refresh() }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: allowedImportTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    handleImport(url: url)
                }
            case .failure:
                break
            }
        }
        .alert(item: $importError) { error in
            Alert(
                title: Text("Импорт модели"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(item: $generalError) { wrapper in
            Alert(
                title: Text("Ошибка"),
                message: Text(wrapper.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var allowedImportTypes: [UTType] {
        if #available(iOS 16.0, *) {
            return [.folder, .package]
        } else {
            return [.item]
        }
    }

    private func modelRow(_ model: LocalModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.displayName)
                    .font(.body)
                    .fontWeight(model.isActive ? .semibold : .regular)
                if model.isActive {
                    Label("Активна", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundColor(.green)
                }
                Spacer()
                Button(action: { manager.setActiveModel(id: model.id) }) {
                    Text(model.isActive ? "Текущая" : "Сделать активной")
                }
                .buttonStyle(.bordered)
                .disabled(model.isActive)
            }

            HStack(spacing: 12) {
                Label(sizeString(bytes: model.sizeBytes), systemImage: "externaldrive")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(installedDateString(model.installedAt), systemImage: "clock")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var emptyPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Нет установленных моделей")
                .font(.headline)
            Text("Импортируйте папку модели (например, из проводника) чтобы активировать on-device MLC.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    private func handleImport(url: URL) {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { url.stopAccessingSecurityScopedResource() }
        }

        do {
            try manager.installModel(from: url)
        } catch let error as ModelManagerError {
            importError = error
        } catch {
            generalError = GeneralError(message: error.localizedDescription)
        }
    }

    private func delete(_ model: LocalModel) {
        do {
            try manager.removeModel(id: model.id)
        } catch let error as ModelManagerError {
            importError = error
        } catch {
            generalError = GeneralError(message: error.localizedDescription)
        }
    }

    private func sizeString(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func installedDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension ModelManagerError: Identifiable {
    var id: String { localizedDescription }
}

private struct GeneralError: Identifiable {
    let id = UUID()
    let message: String
}

struct ModelManagerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { ModelManagerView() }
    }
}
#else
import SwiftUI

struct ModelManagerView: View {
    var body: some View { Text("Только на iOS") }
}
#endif
