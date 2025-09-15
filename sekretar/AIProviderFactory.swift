import Foundation

// MARK: - Provider Factory
enum AIProviderFactory {
    static func current() -> LLMProviderProtocol {
        let defaults = UserDefaults.standard
        if let explicit = defaults.string(forKey: "ai_provider") {
            return from(rawValue: explicit)
        }
        // Auto-select remote when REMOTE_LLM_BASE_URL is configured in Info.plist/UserDefaults
        if let base = (defaults.string(forKey: "REMOTE_LLM_BASE_URL") ?? (Bundle.main.infoDictionary?["REMOTE_LLM_BASE_URL"] as? String)),
           !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return RemoteLLMProvider.shared
        }
        return MLCLLMProvider.shared
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
