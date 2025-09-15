import Foundation

// MARK: - Provider Factory
enum AIProviderFactory {
    static func current() -> LLMProviderProtocol {
        let defaults = UserDefaults.standard
        if let explicit = defaults.string(forKey: "ai_provider") {
            return from(rawValue: explicit)
        }
        // Auto-select remote when REMOTE_LLM_BASE_URL is configured in UserDefaults / RemoteLLM.plist / Info.plist
        if let base = resolveBaseURL(), !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return RemoteLLMProvider.shared
        }
        return MLCLLMProvider.shared
    }

    private static func resolveBaseURL() -> String? {
        let defaults = UserDefaults.standard
        if let s = defaults.string(forKey: "REMOTE_LLM_BASE_URL"), !s.isEmpty { return s }
        if let url = Bundle.main.url(forResource: "RemoteLLM", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let s = dict["REMOTE_LLM_BASE_URL"] as? String, !s.isEmpty { return s }
        if let s = Bundle.main.infoDictionary?["REMOTE_LLM_BASE_URL"] as? String, !s.isEmpty { return s }
        return nil
    }

    static func from(rawValue: String) -> LLMProviderProtocol {
        switch rawValue {
        case "mlc":
            return MLCLLMProvider.shared
        case "remote":
            return RemoteLLMProvider.shared
        case "local":
            return EnhancedLLMProvider.shared
        case "openai":
            // Placeholder until OpenRouter/OpenAI is integrated
            return EnhancedLLMProvider.shared
        case "disabled":
            // For now, route to fallback to keep app usable
            return EnhancedLLMProvider.shared
        default:
            return EnhancedLLMProvider.shared
        }
    }
}
