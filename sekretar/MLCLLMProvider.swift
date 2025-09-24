import Foundation
#if canImport(MLCSwift)
import MLCSwift
#endif

// MARK: - MLC LLM Provider (skeleton with conditional MLCSwift)
// This scaffolding compiles without MLCSwift and falls back to EnhancedLLMProvider.
// When MLCSwift is added to the project, the conditional code will use the real engine.

final class MLCLLMProvider: LLMProviderProtocol {
    static let shared = MLCLLMProvider()
    private init() {}

    // Fallback while MLC runtime not wired
    private let fallback: LLMProviderProtocol = EnhancedLLMProvider.shared

    // MARK: - Engine (available when MLCSwift package is integrated)
    #if canImport(MLCSwift)
    private let engine = MLCEngine()
    private var isLoaded = false

    private func ensureEngineLoaded() async {
        guard !isLoaded else { return }
        // Ensure we have some model directory and pick a model lib name
        ModelManager.shared.ensureDefaultModelIfMissing()
        var modelPath = ModelManager.shared.pathForActiveModel()?.path ?? ""
        // Prefer bundled config if available (dist/bundle copied into app resources)
        if let appConfig = Bundle.main.url(forResource: "mlc-app-config", withExtension: "json") {
            modelPath = appConfig.deletingLastPathComponent().path
        }
        // Default library name used by package unless overridden
        let modelLib = ModelManager.shared.activeModelLibName() ?? "model_iphone"
        await engine.reload(modelPath: modelPath, modelLib: modelLib)
        isLoaded = true
    }
    #endif

    func generateResponse(_ prompt: String) async throws -> String {
        #if canImport(MLCSwift)
        await ensureEngineLoaded()
        var text = ""
        for await res in await engine.chat.completions.create(
            messages: [ChatCompletionMessage(role: .user, content: prompt)]
        ) {
            try Task.checkCancellation()
            if let delta = res.choices.first?.delta.content?.asText() {
                text += delta
            }
        }
        return text.isEmpty ? (try await fallback.generateResponse(prompt)) : text
        #else
        return try await fallback.generateResponse(prompt)
        #endif
    }

    func analyzeTask(_ taskDescription: String) async throws -> TaskAnalysis {
        // TODO: Replace with strict JSON prompt + decode using MLCSwift
        return try await fallback.analyzeTask(taskDescription)
    }

    func generateSmartSuggestions(_ context: String) async throws -> [SmartSuggestion] {
        // TODO: On-device prompt when MLCSwift is available
        return try await fallback.generateSmartSuggestions(context)
    }

    func optimizeSchedule(_ tasks: [TaskSummary]) async throws -> ScheduleOptimization {
        // TODO: On-device reasoning + JSON decoding
        return try await fallback.optimizeSchedule(tasks)
    }

    func detectIntent(_ input: String) async throws -> UserIntent {
        // TODO: On-device intent detection via JSON
        return try await fallback.detectIntent(input)
    }

    func parseEvent(_ description: String) async throws -> EventDraft {
        // TODO: On-device JSON parsing; fallback for now
        return try await fallback.parseEvent(description)
    }
}
