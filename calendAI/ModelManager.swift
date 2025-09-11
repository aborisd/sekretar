import Foundation

// MARK: - Model Metadata
struct LocalModel: Identifiable, Equatable {
    let id: String // e.g., "mlc-llama3-1b-q4f16_1"
    let displayName: String
    let sizeBytes: Int64
    let installedAt: Date
    let isActive: Bool
}

// MARK: - Model Manager (stub)
// Responsible for listing/activating models and providing paths for runtime.
// Networking/download is intentionally omitted in this stub.
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published private(set) var installed: [LocalModel] = []
    @Published private(set) var activeModelID: String?

    private let fm = FileManager.default
    private let baseURL: URL
    private let activeIDKey = "mlc_active_model_id"

    private init() {
        // Application Support /models
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseURL = appSupport.appendingPathComponent("models", isDirectory: true)
        try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
        refresh()
    }

    func refresh() {
        // Discover installed models by folder convention
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
    }

    func pathForActiveModel() -> URL? {
        guard let id = activeModelIDStored() else { return nil }
        return baseURL.appendingPathComponent(id, isDirectory: true)
    }

    /// Best-effort guess for the model library symbol name. Can be overridden later.
    /// When using `mlc_llm package`, the default linked name is typically `model_iphone`.
    func activeModelLibName() -> String? {
        // TODO: Parse mlc-app-config.json if present to derive a specific model_lib
        return "model_iphone"
    }

    func ensureDefaultModelIfMissing(id: String = "mlc-llama3-1b-q4f16_1") {
        // Placeholder: in a later step, copy a bundled starter model if not present
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
}
