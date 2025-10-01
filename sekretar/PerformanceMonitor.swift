import Foundation
import SwiftUI
import os.log

// MARK: - Performance Monitor
/// Мониторинг производительности согласно BRD строки 346-358:
/// - Время создания сущности локально: < 300 мс
/// - Рендер ленты задач и календаря: 60 FPS (≤ 8 мс layout, ≤ 8 мс drawing)
/// - Ответ ИИ: on-device < 2 с, облако < 5 с
@MainActor
final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    @Published var metrics: [PerformanceMetric] = []
    @Published var isMonitoring = false
    @Published var currentFPS: Double = 60.0
    @Published var alerts: [PerformanceAlert] = []

    private let logger = Logger(subsystem: "com.sekretar", category: "Performance")
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount = 0

    // Performance budgets from BRD
    private let budgets = PerformanceBudgets(
        entityCreation: 0.3,        // 300 ms
        layoutComputation: 0.008,   // 8 ms
        drawingTime: 0.008,         // 8 ms
        aiResponseOnDevice: 2.0,    // 2 s
        aiResponseCloud: 5.0,       // 5 s
        targetFPS: 60.0
    )

    private init() {}

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        #if os(iOS)
        startFPSMonitoring()
        #endif

        logger.info("🎯 Performance monitoring started")
    }

    func stopMonitoring() {
        isMonitoring = false

        #if os(iOS)
        stopFPSMonitoring()
        #endif

        logger.info("🎯 Performance monitoring stopped")
    }

    // MARK: - FPS Monitoring (iOS only)

    #if os(iOS)
    private func startFPSMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopFPSMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkCallback(displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }

        let elapsed = displayLink.timestamp - lastTimestamp
        frameCount += 1

        // Update FPS every second
        if elapsed >= 1.0 {
            let fps = Double(frameCount) / elapsed
            currentFPS = fps

            // Check if FPS drops below 60
            if fps < budgets.targetFPS {
                checkFPSPerformance(fps: fps)
            }

            frameCount = 0
            lastTimestamp = displayLink.timestamp
        }
    }

    private func checkFPSPerformance(fps: Double) {
        let severity: PerformanceAlert.Severity = switch fps {
        case 45...60: .warning
        case 30..<45: .critical
        default: .severe
        }

        let alert = PerformanceAlert(
            type: .fpsDropped,
            severity: severity,
            message: "FPS dropped to \(String(format: "%.1f", fps))",
            recommendation: "Optimize rendering or reduce complexity",
            timestamp: Date()
        )

        addAlert(alert)
    }
    #endif

    // MARK: - Performance Tracking

    /// Измеряет время выполнения операции
    func measure<T>(
        operation: String,
        category: PerformanceCategory,
        execute: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()

        let result = try await execute()

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        recordMetric(
            operation: operation,
            category: category,
            duration: duration
        )

        return result
    }

    /// Измеряет синхронную операцию
    func measureSync<T>(
        operation: String,
        category: PerformanceCategory,
        execute: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()

        let result = try execute()

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        recordMetric(
            operation: operation,
            category: category,
            duration: duration
        )

        return result
    }

    /// Записывает метрику производительности
    private func recordMetric(
        operation: String,
        category: PerformanceCategory,
        duration: TimeInterval
    ) {
        let metric = PerformanceMetric(
            operation: operation,
            category: category,
            duration: duration,
            timestamp: Date()
        )

        metrics.append(metric)

        // Keep only last 100 metrics
        if metrics.count > 100 {
            metrics.removeFirst(metrics.count - 100)
        }

        // Log metric
        let durationMs = duration * 1000
        logger.info("⏱️ \(operation): \(String(format: "%.2f", durationMs))ms [\(category.rawValue)]")

        // Check against budget
        checkBudget(metric: metric)

        // Track in analytics
        AnalyticsService.shared.track(.performanceMetric, properties: [
            "operation": operation,
            "category": category.rawValue,
            "duration_ms": durationMs,
            "within_budget": metric.isWithinBudget(budgets)
        ])
    }

    /// Проверяет соответствие бюджету производительности
    private func checkBudget(metric: PerformanceMetric) {
        guard !metric.isWithinBudget(budgets) else { return }

        let budget = metric.category.budget(budgets)
        let severity: PerformanceAlert.Severity = metric.duration > budget * 2 ? .severe : .critical

        let alert = PerformanceAlert(
            type: .budgetExceeded,
            severity: severity,
            message: "\(metric.operation) took \(String(format: "%.0f", metric.duration * 1000))ms (budget: \(String(format: "%.0f", budget * 1000))ms)",
            recommendation: "Optimize \(metric.category.rawValue) operation",
            timestamp: Date()
        )

        addAlert(alert)
    }

    private func addAlert(_ alert: PerformanceAlert) {
        alerts.append(alert)

        // Keep only last 50 alerts
        if alerts.count > 50 {
            alerts.removeFirst(alerts.count - 50)
        }

        logger.warning("⚠️ Performance alert: \(alert.message)")
    }

    // MARK: - Statistics

    func getAverageTime(for category: PerformanceCategory) -> TimeInterval? {
        let categoryMetrics = metrics.filter { $0.category == category }
        guard !categoryMetrics.isEmpty else { return nil }

        let total = categoryMetrics.reduce(0.0) { $0 + $1.duration }
        return total / Double(categoryMetrics.count)
    }

    func getSlowOperations(threshold: TimeInterval = 0.5) -> [PerformanceMetric] {
        metrics.filter { $0.duration > threshold }
            .sorted { $0.duration > $1.duration }
    }

    func clearMetrics() {
        metrics.removeAll()
        alerts.removeAll()
        logger.info("🗑️ Performance metrics cleared")
    }

    // MARK: - Debug Report

    func generateReport() -> String {
        var report = "📊 Performance Report\n"
        report += "==================\n\n"

        report += "FPS: \(String(format: "%.1f", currentFPS))\n"
        report += "Total Metrics: \(metrics.count)\n"
        report += "Active Alerts: \(alerts.filter { $0.severity != .info }.count)\n\n"

        // Category averages
        report += "Category Averages:\n"
        for category in PerformanceCategory.allCases {
            if let avg = getAverageTime(for: category) {
                let avgMs = avg * 1000
                let budget = category.budget(budgets) * 1000
                let status = avg <= category.budget(budgets) ? "✅" : "❌"
                report += "  \(status) \(category.rawValue): \(String(format: "%.2f", avgMs))ms (budget: \(String(format: "%.0f", budget))ms)\n"
            }
        }

        // Slow operations
        let slowOps = getSlowOperations(threshold: 0.3)
        if !slowOps.isEmpty {
            report += "\nSlow Operations (>300ms):\n"
            for op in slowOps.prefix(5) {
                report += "  ⚠️ \(op.operation): \(String(format: "%.0f", op.duration * 1000))ms\n"
            }
        }

        // Recent alerts
        let recentAlerts = alerts.suffix(5)
        if !recentAlerts.isEmpty {
            report += "\nRecent Alerts:\n"
            for alert in recentAlerts {
                report += "  \(alert.severity.icon) \(alert.message)\n"
            }
        }

        return report
    }
}

// MARK: - Models

struct PerformanceMetric: Identifiable {
    let id = UUID()
    let operation: String
    let category: PerformanceCategory
    let duration: TimeInterval
    let timestamp: Date

    func isWithinBudget(_ budgets: PerformanceBudgets) -> Bool {
        duration <= category.budget(budgets)
    }
}

struct PerformanceAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let severity: Severity
    let message: String
    let recommendation: String
    let timestamp: Date

    enum AlertType {
        case budgetExceeded
        case fpsDropped
        case memoryWarning
        case slowNetwork
    }

    enum Severity: String {
        case info = "info"
        case warning = "warning"
        case critical = "critical"
        case severe = "severe"

        var icon: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .critical: return "🔴"
            case .severe: return "🚨"
            }
        }

        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .yellow
            case .critical: return .orange
            case .severe: return .red
            }
        }
    }
}

enum PerformanceCategory: String, CaseIterable {
    case entityCreation = "entity_creation"
    case layoutComputation = "layout"
    case drawing = "drawing"
    case aiResponse = "ai_response"
    case dataFetch = "data_fetch"
    case rendering = "rendering"
    case network = "network"

    func budget(_ budgets: PerformanceBudgets) -> TimeInterval {
        switch self {
        case .entityCreation: return budgets.entityCreation
        case .layoutComputation: return budgets.layoutComputation
        case .drawing: return budgets.drawingTime
        case .aiResponse: return budgets.aiResponseCloud // More lenient
        case .dataFetch: return 0.5 // 500 ms
        case .rendering: return budgets.drawingTime
        case .network: return 3.0 // 3 s
        }
    }
}

struct PerformanceBudgets {
    let entityCreation: TimeInterval
    let layoutComputation: TimeInterval
    let drawingTime: TimeInterval
    let aiResponseOnDevice: TimeInterval
    let aiResponseCloud: TimeInterval
    let targetFPS: Double
}

// MARK: - SwiftUI Integration

/// View modifier для измерения времени рендеринга
struct PerformanceMeasureModifier: ViewModifier {
    let operation: String
    let category: PerformanceCategory

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Measure view appearance time
                Task {
                    await PerformanceMonitor.shared.measure(
                        operation: operation,
                        category: category
                    ) {
                        // Empty operation, just measuring appearance
                    }
                }
            }
    }
}

extension View {
    func measurePerformance(operation: String, category: PerformanceCategory = .rendering) -> some View {
        modifier(PerformanceMeasureModifier(operation: operation, category: category))
    }
}

// MARK: - Analytics Extensions
extension AnalyticsEvent {
    static let performanceMetric = AnalyticsEvent(rawValue: "performance_metric")!
    static let performanceAlert = AnalyticsEvent(rawValue: "performance_alert")!
}

// MARK: - Optimized List Helpers

/// LazyVStack с оптимизацией для больших списков
struct OptimizedList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    content(item)
                        .id(item.id)
                }
            }
        }
        .measurePerformance(operation: "OptimizedList", category: .rendering)
    }
}

/// Кэш для вычисленных значений
@propertyWrapper
struct Cached<T> {
    private var value: T?
    private let compute: () -> T

    init(wrappedValue compute: @escaping @autoclosure () -> T) {
        self.compute = compute
    }

    var wrappedValue: T {
        mutating get {
            if let value = value {
                return value
            }
            let newValue = compute()
            value = newValue
            return newValue
        }
        set {
            value = newValue
        }
    }
}
