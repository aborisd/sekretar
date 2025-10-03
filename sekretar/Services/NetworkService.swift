import Foundation

/// HTTP request method
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// Network error types
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case encodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized
    case networkFailure(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        case .unauthorized:
            return "Unauthorized - please log in again"
        case .networkFailure(let error):
            return "Network failure: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        }
    }
}

/// Response wrapper for API responses
struct APIResponse<T: Decodable>: Decodable {
    let data: T?
    let error: String?
    let message: String?
}

/// Network service for API communication
actor NetworkService {
    static let shared = NetworkService()

    private let session: URLSession
    private let baseURL: String
    private let timeout: TimeInterval = 30.0

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config)

        // Read from config or use default
        #if DEBUG
        self.baseURL = "http://localhost:8000/api/v1"
        #else
        self.baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
            ?? "https://api.sekretar.app/api/v1"
        #endif
    }

    // MARK: - Generic Request

    /// Make a generic HTTP request
    /// - Parameters:
    ///   - endpoint: API endpoint path (e.g., "/auth/login")
    ///   - method: HTTP method
    ///   - body: Optional request body (will be JSON encoded)
    ///   - headers: Optional additional headers
    ///   - requiresAuth: Whether to include JWT token
    /// - Returns: Decoded response of type T
    func request<T: Decodable, B: Encodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        body: B? = nil,
        headers: [String: String]? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        // Build URL
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add authorization if required
        if requiresAuth {
            if let token = await AuthManager.shared.getAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                throw NetworkError.unauthorized
            }
        }

        // Encode body if present
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }

        // Execute request
        let (data, response) = try await session.data(for: request)

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            // Success - decode response
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }

        case 401:
            // Unauthorized - clear token and throw
            await AuthManager.shared.clearTokens()
            throw NetworkError.unauthorized

        case 400...499:
            // Client error - try to extract message
            let errorMessage = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage?.error ?? errorMessage?.message
            )

        case 500...599:
            // Server error
            let errorMessage = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage?.error ?? "Internal server error"
            )

        default:
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Unexpected status code"
            )
        }
    }

    // MARK: - Convenience Methods

    /// GET request without body
    func get<T: Decodable>(
        _ endpoint: String,
        headers: [String: String]? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        return try await request(
            endpoint,
            method: .get,
            body: Optional<String>.none,
            headers: headers,
            requiresAuth: requiresAuth
        )
    }

    /// POST request with body
    func post<T: Decodable, B: Encodable>(
        _ endpoint: String,
        body: B,
        headers: [String: String]? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        return try await request(
            endpoint,
            method: .post,
            body: body,
            headers: headers,
            requiresAuth: requiresAuth
        )
    }

    /// PUT request with body
    func put<T: Decodable, B: Encodable>(
        _ endpoint: String,
        body: B,
        headers: [String: String]? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        return try await request(
            endpoint,
            method: .put,
            body: body,
            headers: headers,
            requiresAuth: requiresAuth
        )
    }

    /// DELETE request
    func delete<T: Decodable>(
        _ endpoint: String,
        headers: [String: String]? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        return try await request(
            endpoint,
            method: .delete,
            body: Optional<String>.none,
            headers: headers,
            requiresAuth: requiresAuth
        )
    }

    // MARK: - File Upload

    /// Upload multipart form data
    func upload<T: Decodable>(
        _ endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        additionalFields: [String: String]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create boundary
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Add auth
        if requiresAuth {
            if let token = await AuthManager.shared.getAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                throw NetworkError.unauthorized
            }
        }

        // Build multipart body
        var body = Data()

        // Add additional fields
        additionalFields?.forEach { key, value in
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Execute
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    // MARK: - Health Check

    /// Check backend health
    func checkHealth() async -> Bool {
        do {
            struct HealthResponse: Decodable {
                let status: String
            }

            let response: HealthResponse = try await get("/health")
            return response.status == "healthy"
        } catch {
            print("❌ [Network] Health check failed: \(error)")
            return false
        }
    }
}
