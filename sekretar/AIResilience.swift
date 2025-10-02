import Foundation

// MARK: - Retry Policy

/// Configuration for retry behavior
public struct RetryPolicy {
    /// Maximum number of retry attempts
    let maxAttempts: Int

    /// Initial delay before first retry (in seconds)
    let initialDelay: TimeInterval

    /// Maximum delay between retries (in seconds)
    let maxDelay: TimeInterval

    /// Multiplier for exponential backoff
    let backoffMultiplier: Double

    /// Add random jitter to prevent thundering herd
    let jitterRange: ClosedRange<Double>

    /// Which errors should trigger retry
    let retryableErrors: Set<RetryableError>

    public static let `default` = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 0.1,
        maxDelay: 10.0,
        backoffMultiplier: 2.0,
        jitterRange: 0.8...1.2,
        retryableErrors: [.network, .timeout, .rateLimit, .temporary]
    )

    public static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.05,
        maxDelay: 30.0,
        backoffMultiplier: 1.5,
        jitterRange: 0.9...1.1,
        retryableErrors: [.network, .timeout, .rateLimit, .temporary, .serverError]
    )

    public static let conservative = RetryPolicy(
        maxAttempts: 2,
        initialDelay: 1.0,
        maxDelay: 5.0,
        backoffMultiplier: 3.0,
        jitterRange: 0.5...1.5,
        retryableErrors: [.network, .timeout]
    )

    /// Calculate delay for a specific attempt
    func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = initialDelay * pow(backoffMultiplier, Double(attempt - 1))
        let clampedDelay = min(exponentialDelay, maxDelay)
        let jitter = Double.random(in: jitterRange)
        return clampedDelay * jitter
    }
}

// MARK: - Retryable Errors

public enum RetryableError: Hashable {
    case network
    case timeout
    case rateLimit
    case temporary
    case serverError
    case serviceUnavailable
}

// MARK: - Circuit Breaker

/// Circuit breaker to prevent cascading failures
public actor CircuitBreaker {

    public enum State {
        case closed      // Normal operation
        case open        // Failing, reject requests
        case halfOpen    // Testing if service recovered
    }

    // Configuration
    private let failureThreshold: Int
    private let successThreshold: Int
    private let timeout: TimeInterval
    private let resetTimeout: TimeInterval

    // State
    private var state: State = .closed
    private var failureCount: Int = 0
    private var successCount: Int = 0
    private var lastFailureTime: Date?
    private var stateChangeTime: Date = Date()

    // Metrics
    private var totalRequests: Int = 0
    private var totalFailures: Int = 0
    private var totalSuccesses: Int = 0
    private var circuitOpenCount: Int = 0

    public init(
        failureThreshold: Int = 5,
        successThreshold: Int = 2,
        timeout: TimeInterval = 60,
        resetTimeout: TimeInterval = 30
    ) {
        self.failureThreshold = failureThreshold
        self.successThreshold = successThreshold
        self.timeout = timeout
        self.resetTimeout = resetTimeout
    }

    /// Check if request should be allowed
    public func shouldAllowRequest() -> Bool {
        switch state {
        case .closed:
            return true

        case .open:
            // Check if we should transition to half-open
            if Date().timeIntervalSince(stateChangeTime) > resetTimeout {
                transition(to: .halfOpen)
                return true
            }
            return false

        case .halfOpen:
            return true
        }
    }

    /// Record successful request
    public func recordSuccess() {
        totalRequests += 1
        totalSuccesses += 1

        switch state {
        case .closed:
            failureCount = 0

        case .halfOpen:
            successCount += 1
            if successCount >= successThreshold {
                transition(to: .closed)
            }

        case .open:
            break
        }
    }

    /// Record failed request
    public func recordFailure() {
        totalRequests += 1
        totalFailures += 1
        lastFailureTime = Date()

        switch state {
        case .closed:
            failureCount += 1
            if failureCount >= failureThreshold {
                transition(to: .open)
            }

        case .halfOpen:
            transition(to: .open)

        case .open:
            break
        }
    }

    /// Get current state
    public func getState() -> State {
        return state
    }

    /// Get metrics
    public func getMetrics() -> CircuitBreakerMetrics {
        CircuitBreakerMetrics(
            state: state,
            totalRequests: totalRequests,
            totalFailures: totalFailures,
            totalSuccesses: totalSuccesses,
            failureRate: totalRequests > 0 ? Double(totalFailures) / Double(totalRequests) : 0,
            circuitOpenCount: circuitOpenCount,
            lastFailureTime: lastFailureTime,
            stateChangeTime: stateChangeTime
        )
    }

    /// Reset circuit breaker
    public func reset() {
        state = .closed
        failureCount = 0
        successCount = 0
        lastFailureTime = nil
        stateChangeTime = Date()
    }

    private func transition(to newState: State) {
        let oldState = state
        state = newState
        stateChangeTime = Date()

        // Reset counts
        failureCount = 0
        successCount = 0

        // Track circuit opens
        if newState == .open {
            circuitOpenCount += 1
        }

        print("CircuitBreaker: \(oldState) → \(newState)")
    }
}

// MARK: - Circuit Breaker Metrics

public struct CircuitBreakerMetrics {
    public let state: CircuitBreaker.State
    public let totalRequests: Int
    public let totalFailures: Int
    public let totalSuccesses: Int
    public let failureRate: Double
    public let circuitOpenCount: Int
    public let lastFailureTime: Date?
    public let stateChangeTime: Date
}

// MARK: - Resilient Executor

/// Execute async operations with retry and circuit breaker
public final class ResilientExecutor {

    private let retryPolicy: RetryPolicy
    private let circuitBreaker: CircuitBreaker
    private let timeout: TimeInterval

    public init(
        retryPolicy: RetryPolicy = .default,
        circuitBreaker: CircuitBreaker = CircuitBreaker(),
        timeout: TimeInterval = 30
    ) {
        self.retryPolicy = retryPolicy
        self.circuitBreaker = circuitBreaker
        self.timeout = timeout
    }

    /// Execute operation with resilience patterns
    public func execute<T>(
        operation: @escaping () async throws -> T,
        fallback: (() async throws -> T)? = nil
    ) async throws -> T {
        // Check circuit breaker
        let canProceed = await circuitBreaker.shouldAllowRequest()
        guard canProceed else {
            if let fallback = fallback {
                return try await fallback()
            }
            throw ResilienceError.circuitOpen
        }

        // Try with retries
        var lastError: Error?

        for attempt in 1...retryPolicy.maxAttempts {
            do {
                // Execute with timeout
                let result = try await withTimeout(seconds: timeout) {
                    try await operation()
                }

                // Record success
                await circuitBreaker.recordSuccess()
                return result

            } catch {
                lastError = error

                // Check if error is retryable
                guard shouldRetry(error: error, attempt: attempt) else {
                    await circuitBreaker.recordFailure()
                    throw error
                }

                // Wait before retry
                if attempt < retryPolicy.maxAttempts {
                    let delay = retryPolicy.delay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // All retries exhausted
        await circuitBreaker.recordFailure()

        // Try fallback if available
        if let fallback = fallback {
            return try await fallback()
        }

        throw lastError ?? ResilienceError.unknown
    }

    private func shouldRetry(error: Error, attempt: Int) -> Bool {
        // Check if we have retries left
        guard attempt < retryPolicy.maxAttempts else {
            return false
        }

        // Map error to retryable category
        let retryableError = mapToRetryableError(error)
        return retryPolicy.retryableErrors.contains(retryableError)
    }

    private func mapToRetryableError(_ error: Error) -> RetryableError {
        // Map common errors to retryable categories
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .network
            case .timedOut:
                return .timeout
            case .cannotFindHost, .cannotConnectToHost:
                return .temporary
            default:
                return .network
            }
        }

        // Check for HTTP status codes if available
        if let httpError = error as? HTTPError {
            switch httpError.statusCode {
            case 429:
                return .rateLimit
            case 500...599:
                return .serverError
            case 503:
                return .serviceUnavailable
            default:
                return .temporary
            }
        }

        return .temporary
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add main operation
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ResilienceError.timeout
            }

            // Return first to complete
            guard let result = try await group.next() else {
                throw ResilienceError.unknown
            }

            // Cancel remaining task
            group.cancelAll()

            return result
        }
    }
}

// MARK: - Errors

public enum ResilienceError: LocalizedError {
    case circuitOpen
    case timeout
    case unknown
    case maxRetriesExceeded

    public var errorDescription: String? {
        switch self {
        case .circuitOpen:
            return "Service is temporarily unavailable (circuit breaker open)"
        case .timeout:
            return "Operation timed out"
        case .unknown:
            return "Unknown error occurred"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        }
    }
}

public struct HTTPError: Error {
    let statusCode: Int
    let message: String?
}

// MARK: - Timeout Policy

public struct TimeoutPolicy {
    let connect: TimeInterval
    let read: TimeInterval
    let write: TimeInterval
    let total: TimeInterval

    public static let `default` = TimeoutPolicy(
        connect: 10,
        read: 30,
        write: 30,
        total: 60
    )

    public static let fast = TimeoutPolicy(
        connect: 5,
        read: 10,
        write: 10,
        total: 20
    )

    public static let slow = TimeoutPolicy(
        connect: 30,
        read: 60,
        write: 60,
        total: 120
    )
}

// MARK: - Rate Limiter

/// Token bucket rate limiter
public actor RateLimiter {
    private let capacity: Int
    private let refillRate: Double // tokens per second
    private var tokens: Double
    private var lastRefillTime: Date

    public init(capacity: Int, refillRate: Double) {
        self.capacity = capacity
        self.refillRate = refillRate
        self.tokens = Double(capacity)
        self.lastRefillTime = Date()
    }

    /// Try to acquire tokens
    public func acquire(_ count: Int = 1) async -> Bool {
        refillTokens()

        if tokens >= Double(count) {
            tokens -= Double(count)
            return true
        }

        return false
    }

    /// Wait until tokens are available
    public func acquireWithWait(_ count: Int = 1) async throws {
        while true {
            if await acquire(count) {
                return
            }

            // Calculate wait time
            let tokensNeeded = Double(count) - tokens
            let waitTime = tokensNeeded / refillRate

            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
    }

    private func refillTokens() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefillTime)
        let newTokens = elapsed * refillRate

        tokens = min(tokens + newTokens, Double(capacity))
        lastRefillTime = now
    }

    /// Get current token count
    public func getTokenCount() -> Double {
        refillTokens()
        return tokens
    }
}