import Foundation
import os.log

/// Comprehensive metrics collection for AI operations
public final class AIMetricsCollector {

    // MARK: - Metric Types

    public struct LLMMetrics {
        public let operation: String
        public let provider: String
        public let latency: TimeInterval
        public let inputTokens: Int
        public let outputTokens: Int
        public let cost: Double
        public let success: Bool
        public let error: String?
        public let cacheHit: Bool
        public let timestamp: Date

        public var totalTokens: Int {
            inputTokens + outputTokens
        }
    }

    public struct ParsingMetrics {
        public let input: String
        public let parseType: String
        public let success: Bool
        public let fallbackUsed: Bool
        public let latency: TimeInterval
        public let confidence: Double?
        public let error: String?
        public let timestamp: Date
    }

    public struct ValidationMetrics {
        public let schemaType: String
        public let valid: Bool
        public let errors: [String]
        public let latency: TimeInterval
        public let timestamp: Date
    }

    public struct UserActionMetrics {
        public let actionType: String
        public let accepted: Bool
        public let modifiedBeforeAccept: Bool
        public let timeToDecision: TimeInterval
        public let confidence: Double
        public let timestamp: Date
    }

    public struct SchedulingMetrics {
        public let tasksScheduled: Int
        public let slotsFound: Int
        public let conflictsDetected: Int
        public let fragmentationScore: Double
        public let productivityScore: Double
        public let latency: TimeInterval
        public let timestamp: Date
    }

    // MARK: - Aggregated Metrics

    public struct AggregatedMetrics: Codable {
        // LLM Performance
        public let totalLLMCalls: Int
        public let llmSuccessRate: Double
        public let averageLatency: TimeInterval
        public let p50Latency: TimeInterval
        public let p95Latency: TimeInterval
        public let p99Latency: TimeInterval
        public let totalTokensUsed: Int
        public let totalCost: Double
        public let cacheHitRate: Double

        // Parsing Performance
        public let totalParseAttempts: Int
        public let parseSuccessRate: Double
        public let fallbackRate: Double
        public let averageParseLatency: TimeInterval

        // User Interaction
        public let totalActions: Int
        public let acceptanceRate: Double
        public let modificationRate: Double
        public let averageTimeToDecision: TimeInterval

        // System Health
        public let errorRate: Double
        public let circuitBreakerTrips: Int
        public let retryRate: Double
        public let timeWindow: DateInterval
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.sekretar.ai", category: "metrics")
    private let metricsQueue = DispatchQueue(label: "com.sekretar.ai.metrics", attributes: .concurrent)
    private let persistence: MetricsPersistence

    // In-memory buffers
    private var llmMetrics: [LLMMetrics] = []
    private var parsingMetrics: [ParsingMetrics] = []
    private var validationMetrics: [ValidationMetrics] = []
    private var userActionMetrics: [UserActionMetrics] = []
    private var schedulingMetrics: [SchedulingMetrics] = []

    // Real-time counters
    private var circuitBreakerTrips: Int = 0
    private var retryCount: Int = 0

    // Configuration
    private let maxBufferSize: Int
    private let flushInterval: TimeInterval
    private var flushTimer: Timer?

    // MARK: - Initialization

    public init(
        maxBufferSize: Int = 1000,
        flushInterval: TimeInterval = 60
    ) {
        self.maxBufferSize = maxBufferSize
        self.flushInterval = flushInterval
        self.persistence = MetricsPersistence()

        setupFlushTimer()
        loadHistoricalMetrics()
    }

    deinit {
        flushTimer?.invalidate()
        flush()
    }

    // MARK: - Recording Methods

    public func recordLLMCall(
        operation: String,
        provider: String,
        latency: TimeInterval,
        inputTokens: Int,
        outputTokens: Int,
        success: Bool,
        error: String? = nil,
        cacheHit: Bool = false
    ) {
        let metric = LLMMetrics(
            operation: operation,
            provider: provider,
            latency: latency,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cost: calculateCost(inputTokens: inputTokens, outputTokens: outputTokens, provider: provider),
            success: success,
            error: error,
            cacheHit: cacheHit,
            timestamp: Date()
        )

        metricsQueue.async(flags: .barrier) { [weak self] in
            self?.llmMetrics.append(metric)
            self?.checkBufferSize()
        }

        // Log significant events
        if !success {
            logger.error("LLM call failed: \(operation) - \(error ?? "Unknown error")")
        }
        if latency > 5.0 {
            logger.warning("Slow LLM call: \(operation) took \(latency)s")
        }
    }

    public func recordParsing(
        input: String,
        parseType: String,
        success: Bool,
        fallbackUsed: Bool,
        latency: TimeInterval,
        confidence: Double? = nil,
        error: String? = nil
    ) {
        let metric = ParsingMetrics(
            input: String(input.prefix(100)), // Truncate for storage
            parseType: parseType,
            success: success,
            fallbackUsed: fallbackUsed,
            latency: latency,
            confidence: confidence,
            error: error,
            timestamp: Date()
        )

        metricsQueue.async(flags: .barrier) { [weak self] in
            self?.parsingMetrics.append(metric)
            self?.checkBufferSize()
        }
    }

    public func recordValidation(
        schemaType: String,
        valid: Bool,
        errors: [String],
        latency: TimeInterval
    ) {
        let metric = ValidationMetrics(
            schemaType: schemaType,
            valid: valid,
            errors: errors,
            latency: latency,
            timestamp: Date()
        )

        metricsQueue.async(flags: .barrier) { [weak self] in
            self?.validationMetrics.append(metric)
            self?.checkBufferSize()
        }

        if !valid {
            logger.warning("Schema validation failed: \(schemaType) - \(errors.joined(separator: ", "))")
        }
    }

    public func recordUserAction(
        actionType: String,
        accepted: Bool,
        modifiedBeforeAccept: Bool,
        timeToDecision: TimeInterval,
        confidence: Double
    ) {
        let metric = UserActionMetrics(
            actionType: actionType,
            accepted: accepted,
            modifiedBeforeAccept: modifiedBeforeAccept,
            timeToDecision: timeToDecision,
            confidence: confidence,
            timestamp: Date()
        )

        metricsQueue.async(flags: .barrier) { [weak self] in
            self?.userActionMetrics.append(metric)
            self?.checkBufferSize()
        }
    }

    public func recordScheduling(
        tasksScheduled: Int,
        slotsFound: Int,
        conflictsDetected: Int,
        fragmentationScore: Double,
        productivityScore: Double,
        latency: TimeInterval
    ) {
        let metric = SchedulingMetrics(
            tasksScheduled: tasksScheduled,
            slotsFound: slotsFound,
            conflictsDetected: conflictsDetected,
            fragmentationScore: fragmentationScore,
            productivityScore: productivityScore,
            latency: latency,
            timestamp: Date()
        )

        metricsQueue.async(flags: .barrier) { [weak self] in
            self?.schedulingMetrics.append(metric)
            self?.checkBufferSize()
        }
    }

    public func recordCircuitBreakerTrip() {
        metricsQueue.async(flags: .barrier) { [weak self] in
            self?.circuitBreakerTrips += 1
        }
    }

    public func recordRetry() {
        metricsQueue.async(flags: .barrier) { [weak self] in
            self?.retryCount += 1
        }
    }

    // MARK: - Aggregation

    public func getAggregatedMetrics(for window: DateInterval? = nil) -> AggregatedMetrics {
        metricsQueue.sync {
            let timeWindow = window ?? DateInterval(
                start: Date().addingTimeInterval(-3600), // Last hour
                end: Date()
            )

            // Filter metrics by time window
            let filteredLLM = llmMetrics.filter { timeWindow.contains($0.timestamp) }
            let filteredParsing = parsingMetrics.filter { timeWindow.contains($0.timestamp) }
            let filteredActions = userActionMetrics.filter { timeWindow.contains($0.timestamp) }

            // LLM metrics
            let llmLatencies = filteredLLM.map { $0.latency }.sorted()
            let llmSuccess = filteredLLM.filter { $0.success }.count
            let cacheHits = filteredLLM.filter { $0.cacheHit }.count

            // Parsing metrics
            let parseSuccess = filteredParsing.filter { $0.success }.count
            let fallbacks = filteredParsing.filter { $0.fallbackUsed }.count

            // User action metrics
            let accepted = filteredActions.filter { $0.accepted }.count
            let modified = filteredActions.filter { $0.modifiedBeforeAccept }.count

            return AggregatedMetrics(
                totalLLMCalls: filteredLLM.count,
                llmSuccessRate: filteredLLM.isEmpty ? 1.0 : Double(llmSuccess) / Double(filteredLLM.count),
                averageLatency: llmLatencies.isEmpty ? 0 : llmLatencies.reduce(0, +) / Double(llmLatencies.count),
                p50Latency: percentile(llmLatencies, 0.5),
                p95Latency: percentile(llmLatencies, 0.95),
                p99Latency: percentile(llmLatencies, 0.99),
                totalTokensUsed: filteredLLM.reduce(0) { $0 + $1.totalTokens },
                totalCost: filteredLLM.reduce(0) { $0 + $1.cost },
                cacheHitRate: filteredLLM.isEmpty ? 0 : Double(cacheHits) / Double(filteredLLM.count),
                totalParseAttempts: filteredParsing.count,
                parseSuccessRate: filteredParsing.isEmpty ? 1.0 : Double(parseSuccess) / Double(filteredParsing.count),
                fallbackRate: filteredParsing.isEmpty ? 0 : Double(fallbacks) / Double(filteredParsing.count),
                averageParseLatency: filteredParsing.isEmpty ? 0 : filteredParsing.map { $0.latency }.reduce(0, +) / Double(filteredParsing.count),
                totalActions: filteredActions.count,
                acceptanceRate: filteredActions.isEmpty ? 1.0 : Double(accepted) / Double(filteredActions.count),
                modificationRate: filteredActions.isEmpty ? 0 : Double(modified) / Double(filteredActions.count),
                averageTimeToDecision: filteredActions.isEmpty ? 0 : filteredActions.map { $0.timeToDecision }.reduce(0, +) / Double(filteredActions.count),
                errorRate: filteredLLM.isEmpty ? 0 : Double(filteredLLM.count - llmSuccess) / Double(filteredLLM.count),
                circuitBreakerTrips: circuitBreakerTrips,
                retryRate: filteredLLM.isEmpty ? 0 : Double(retryCount) / Double(filteredLLM.count),
                timeWindow: timeWindow
            )
        }
    }

    // MARK: - Export

    public func exportMetrics(format: ExportFormat = .json) -> Data? {
        let metrics = getAggregatedMetrics()

        switch format {
        case .json:
            return try? JSONEncoder().encode(metrics)
        case .csv:
            return exportAsCSV(metrics)
        }
    }

    public enum ExportFormat {
        case json
        case csv
    }

    // MARK: - Alerts

    public func checkAlerts() -> [Alert] {
        let metrics = getAggregatedMetrics()
        var alerts: [Alert] = []

        // High error rate
        if metrics.errorRate > 0.1 {
            alerts.append(Alert(
                level: .critical,
                message: "High error rate: \(String(format: "%.1f%%", metrics.errorRate * 100))",
                metric: "error_rate",
                value: metrics.errorRate
            ))
        }

        // Slow response times
        if metrics.p95Latency > 5.0 {
            alerts.append(Alert(
                level: .warning,
                message: "Slow LLM responses: p95 = \(String(format: "%.2fs", metrics.p95Latency))",
                metric: "p95_latency",
                value: metrics.p95Latency
            ))
        }

        // Low cache hit rate
        if metrics.totalLLMCalls > 10 && metrics.cacheHitRate < 0.3 {
            alerts.append(Alert(
                level: .info,
                message: "Low cache hit rate: \(String(format: "%.1f%%", metrics.cacheHitRate * 100))",
                metric: "cache_hit_rate",
                value: metrics.cacheHitRate
            ))
        }

        // Circuit breaker trips
        if metrics.circuitBreakerTrips > 0 {
            alerts.append(Alert(
                level: .warning,
                message: "Circuit breaker tripped \(metrics.circuitBreakerTrips) times",
                metric: "circuit_breaker_trips",
                value: Double(metrics.circuitBreakerTrips)
            ))
        }

        // Low user acceptance
        if metrics.totalActions > 10 && metrics.acceptanceRate < 0.7 {
            alerts.append(Alert(
                level: .warning,
                message: "Low user acceptance rate: \(String(format: "%.1f%%", metrics.acceptanceRate * 100))",
                metric: "acceptance_rate",
                value: metrics.acceptanceRate
            ))
        }

        return alerts
    }

    public struct Alert {
        public enum Level {
            case info
            case warning
            case critical
        }

        public let level: Level
        public let message: String
        public let metric: String
        public let value: Double
        public let timestamp: Date = Date()
    }

    // MARK: - Private Methods

    private func setupFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            self?.flush()
        }
    }

    private func checkBufferSize() {
        let totalSize = llmMetrics.count + parsingMetrics.count + validationMetrics.count +
                       userActionMetrics.count + schedulingMetrics.count

        if totalSize >= maxBufferSize {
            flush()
        }
    }

    private func flush() {
        metricsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // Persist metrics
            self.persistence.save(
                llm: self.llmMetrics,
                parsing: self.parsingMetrics,
                validation: self.validationMetrics,
                userAction: self.userActionMetrics,
                scheduling: self.schedulingMetrics
            )

            // Clear buffers, keeping recent metrics for real-time queries
            let cutoff = Date().addingTimeInterval(-300) // Keep last 5 minutes

            self.llmMetrics = self.llmMetrics.filter { $0.timestamp > cutoff }
            self.parsingMetrics = self.parsingMetrics.filter { $0.timestamp > cutoff }
            self.validationMetrics = self.validationMetrics.filter { $0.timestamp > cutoff }
            self.userActionMetrics = self.userActionMetrics.filter { $0.timestamp > cutoff }
            self.schedulingMetrics = self.schedulingMetrics.filter { $0.timestamp > cutoff }
        }
    }

    private func loadHistoricalMetrics() {
        // Load recent metrics from persistence on startup
        metricsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            if let recent = self.persistence.loadRecent(since: Date().addingTimeInterval(-300)) {
                self.llmMetrics = recent.llm
                self.parsingMetrics = recent.parsing
                self.validationMetrics = recent.validation
                self.userActionMetrics = recent.userAction
                self.schedulingMetrics = recent.scheduling
            }
        }
    }

    private func calculateCost(inputTokens: Int, outputTokens: Int, provider: String) -> Double {
        // Approximate costs per 1K tokens (adjust based on actual provider rates)
        let rates: [String: (input: Double, output: Double)] = [
            "openai-gpt4": (0.03, 0.06),
            "openai-gpt3.5": (0.001, 0.002),
            "anthropic-claude": (0.008, 0.024),
            "local": (0.0, 0.0)
        ]

        let rate = rates[provider] ?? (0.001, 0.002) // Default to GPT-3.5 rates
        return (Double(inputTokens) * rate.input + Double(outputTokens) * rate.output) / 1000.0
    }

    private func percentile(_ values: [TimeInterval], _ p: Double) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        let index = Int(Double(values.count - 1) * p)
        return values[index]
    }

    private func exportAsCSV(_ metrics: AggregatedMetrics) -> Data? {
        var csv = "Metric,Value\n"
        csv += "Total LLM Calls,\(metrics.totalLLMCalls)\n"
        csv += "LLM Success Rate,\(metrics.llmSuccessRate)\n"
        csv += "Average Latency,\(metrics.averageLatency)\n"
        csv += "P95 Latency,\(metrics.p95Latency)\n"
        csv += "Total Tokens,\(metrics.totalTokensUsed)\n"
        csv += "Total Cost,\(metrics.totalCost)\n"
        csv += "Cache Hit Rate,\(metrics.cacheHitRate)\n"
        csv += "Parse Success Rate,\(metrics.parseSuccessRate)\n"
        csv += "User Acceptance Rate,\(metrics.acceptanceRate)\n"
        return csv.data(using: .utf8)
    }
}

// MARK: - Metrics Persistence

private class MetricsPersistence {
    private let documentsDirectory: URL
    private let metricsFile: URL

    init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        metricsFile = documentsDirectory.appendingPathComponent("ai_metrics.json")
    }

    func save(
        llm: [AIMetricsCollector.LLMMetrics],
        parsing: [AIMetricsCollector.ParsingMetrics],
        validation: [AIMetricsCollector.ValidationMetrics],
        userAction: [AIMetricsCollector.UserActionMetrics],
        scheduling: [AIMetricsCollector.SchedulingMetrics]
    ) {
        // For production, implement proper database storage
        // This is a simplified version for demonstration
    }

    func loadRecent(since: Date) -> (
        llm: [AIMetricsCollector.LLMMetrics],
        parsing: [AIMetricsCollector.ParsingMetrics],
        validation: [AIMetricsCollector.ValidationMetrics],
        userAction: [AIMetricsCollector.UserActionMetrics],
        scheduling: [AIMetricsCollector.SchedulingMetrics]
    )? {
        // Load from persistent storage
        return nil
    }
}

// MARK: - Metrics Dashboard View Model

@MainActor
public class AIMetricsDashboardViewModel: ObservableObject {
    @Published var metrics: AIMetricsCollector.AggregatedMetrics?
    @Published var alerts: [AIMetricsCollector.Alert] = []
    @Published var isLoading = false

    private let collector: AIMetricsCollector
    private var refreshTimer: Timer?

    public init(collector: AIMetricsCollector) {
        self.collector = collector
        startAutoRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    public func refresh() {
        isLoading = true
        Task {
            metrics = collector.getAggregatedMetrics()
            alerts = collector.checkAlerts()
            isLoading = false
        }
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    public func exportMetrics() -> URL? {
        guard let data = collector.exportMetrics(format: .csv) else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai_metrics_\(Date().timeIntervalSince1970).csv")

        try? data.write(to: tempURL)
        return tempURL
    }
}

// MARK: - Shared Instance

extension AIMetricsCollector {
    static let shared = AIMetricsCollector()
}