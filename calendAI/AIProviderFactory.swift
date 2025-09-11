import Foundation

// MARK: - Provider Factory
enum AIProviderFactory {
    static func current() -> LLMProviderProtocol {
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: "ai_provider") ?? "mlc"
        return from(rawValue: raw)
    }

    static func from(rawValue: String) -> LLMProviderProtocol {
        switch rawValue {
        case "mlc":
            return MLCLLMProvider.shared
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

