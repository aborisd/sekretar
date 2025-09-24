import Foundation

// MARK: - Model Metadata
struct LocalModel: Identifiable, Equatable {
    let id: String // e.g., "mlc-llama3-1b-q4f16_1"
    let displayName: String
    let sizeBytes: Int64
    let installedAt: Date
    let isActive: Bool
}

enum ModelManagerError: LocalizedError {
    case unsupportedFile
    case activeModelDeletion

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return Locale.current.identifier.lowercased().hasPrefix("ru")
                ? "Этот формат не поддерживается. Выберите папку модели."
                : "Unsupported format. Please choose a model folder."
        case .activeModelDeletion:
            return "Нельзя удалить активную модель. Сначала выберите другую."
        }
    }
}

// MARK: - Model Manager (runtime + local storage)
// Responsible for listing/activating models and providing paths for runtime.
// Networking/download is intentionally omitted in this stub.
@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published private(set) var installed: [LocalModel] = []
    @Published private(set) var activeModelID: String?

    private let fm = FileManager.default
    private let baseURL: URL
    private let activeIDKey = "mlc_active_model_id"

    private init() {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseURL = appSupport.appendingPathComponent("models", isDirectory: true)
        try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
        refresh()
    }

    var modelsDirectory: URL { baseURL }

    func refresh() {
        var results: [LocalModel] = []
        if let items = try? fm.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]) {
            for url in items {
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                let id = url.lastPathComponent
                let attrs = (try? fm.attributesOfItem(atPath: url.path)) ?? [:]
                let size = (try? directorySize(at: url)) ?? 0
                let installedAt = (attrs[.creationDate] as? Date) ?? Date()
                let isActive = id == activeModelIDStored()
                results.append(LocalModel(id: id, displayName: id, sizeBytes: size, installedAt: installedAt, isActive: isActive))
            }
        }
        installed = results.sorted { $0.installedAt < $1.installedAt }
        activeModelID = activeModelIDStored()
    }

    func setActiveModel(id: String) {
        UserDefaults.standard.set(id, forKey: activeIDKey)
        activeModelID = id
        objectWillChange.send()
        refresh()
    }

    func removeModel(id: String) throws {
        guard id != activeModelIDStored() else { throw ModelManagerError.activeModelDeletion }
        let url = baseURL.appendingPathComponent(id, isDirectory: true)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        refresh()
    }

    func installModel(from sourceURL: URL) throws {
        let targetName = sanitizedName(from: sourceURL)
        let targetURL = uniqueTargetURL(for: targetName)

        guard sourceURL.hasDirectoryPath else {
            throw ModelManagerError.unsupportedFile
        }

        try fm.copyItem(at: sourceURL, to: targetURL)
        refresh()
    }

    func pathForActiveModel() -> URL? {
        guard let id = activeModelIDStored() else { return nil }
        return baseURL.appendingPathComponent(id, isDirectory: true)
    }

    func activeModelLibName() -> String? {
        return "model_iphone"
    }

    func ensureDefaultModelIfMissing(id: String = "tinyllama-1.1b-chat-v1.0-q4f16_1") {
        let modelURL = baseURL.appendingPathComponent(id, isDirectory: true)
        if !fm.fileExists(atPath: modelURL.path) {
            try? fm.createDirectory(at: modelURL, withIntermediateDirectories: true)
        }
        if activeModelIDStored() == nil { setActiveModel(id: id) }
        refresh()
    }

    private func activeModelIDStored() -> String? {
        UserDefaults.standard.string(forKey: activeIDKey)
    }

    private func directorySize(at url: URL) throws -> Int64 {
        var size: Int64 = 0
        let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])
        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values.isRegularFile == true {
                size += Int64(values.fileSize ?? 0)
            }
        }
        return size
    }

    private func sanitizedName(from url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filteredScalars = base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let name = String(filteredScalars)
        return name.isEmpty ? "model" : name
    }

    private func uniqueTargetURL(for name: String) -> URL {
        var candidate = baseURL.appendingPathComponent(name, isDirectory: true)
        var index = 1
        while fm.fileExists(atPath: candidate.path) {
            candidate = baseURL.appendingPathComponent("\(name)-\(index)", isDirectory: true)
            index += 1
        }
        return candidate
    }

}
