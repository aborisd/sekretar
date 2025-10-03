import Foundation
import Security
import AuthenticationServices

/// Authentication state
enum AuthState {
    case unauthenticated
    case authenticated(userId: String, tier: String)
    case loading
}

/// Subscription tier
enum SubscriptionTier: String, Codable {
    case free = "free"
    case basic = "basic"
    case pro = "pro"
    case premium = "premium"
    case teams = "teams"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .basic: return "Basic"
        case .pro: return "Pro"
        case .premium: return "Premium"
        case .teams: return "Teams"
        }
    }
}

/// User info from backend
struct UserInfo: Codable {
    let id: String
    let email: String
    let tier: String
    let createdAt: Date?
    let lastSyncAt: Date?

    var subscriptionTier: SubscriptionTier {
        SubscriptionTier(rawValue: tier) ?? .free
    }
}

/// Login request
struct LoginRequest: Codable {
    let email: String
    let password: String
}

/// Register request
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let fullName: String?
}

/// Apple Sign In request
struct AppleSignInRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let email: String?
    let fullName: String?
}

/// Auth response from backend
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: UserInfo
}

/// Authentication manager using Keychain for secure token storage
actor AuthManager: ObservableObject {
    static let shared = AuthManager()

    // Keychain keys
    private let accessTokenKey = "com.sekretar.accessToken"
    private let refreshTokenKey = "com.sekretar.refreshToken"
    private let userInfoKey = "com.sekretar.userInfo"

    @MainActor @Published private(set) var authState: AuthState = .unauthenticated
    @MainActor @Published private(set) var currentUser: UserInfo?

    private init() {
        // Initialize auth state from keychain on startup
        Task {
            await loadAuthState()
        }
    }

    // MARK: - Auth State Management

    /// Load auth state from keychain
    private func loadAuthState() async {
        if let token = await getAccessToken(),
           let userInfo = await getUserInfo() {
            await MainActor.run {
                self.authState = .authenticated(userId: userInfo.id, tier: userInfo.tier)
                self.currentUser = userInfo
            }
        } else {
            await MainActor.run {
                self.authState = .unauthenticated
                self.currentUser = nil
            }
        }
    }

    // MARK: - Login/Register

    /// Login with email and password
    func login(email: String, password: String) async throws {
        await MainActor.run { authState = .loading }

        let request = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await NetworkService.shared.post(
            "/auth/login",
            body: request
        )

        try await saveAuthResponse(response)
    }

    /// Register new account
    func register(email: String, password: String, fullName: String?) async throws {
        await MainActor.run { authState = .loading }

        let request = RegisterRequest(email: email, password: password, fullName: fullName)
        let response: AuthResponse = try await NetworkService.shared.post(
            "/auth/register",
            body: request
        )

        try await saveAuthResponse(response)
    }

    /// Sign in with Apple
    func signInWithApple(authorization: ASAuthorization) async throws {
        await MainActor.run { authState = .loading }

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid Apple ID credential"
            ])
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authCodeData = appleIDCredential.authorizationCode,
              let authCode = String(data: authCodeData, encoding: .utf8) else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Missing Apple ID tokens"
            ])
        }

        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName.map { nameComponents in
            [nameComponents.givenName, nameComponents.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
        }

        let request = AppleSignInRequest(
            identityToken: identityToken,
            authorizationCode: authCode,
            email: email,
            fullName: fullName
        )

        let response: AuthResponse = try await NetworkService.shared.post(
            "/auth/apple",
            body: request
        )

        try await saveAuthResponse(response)
    }

    /// Logout - clear all tokens
    func logout() async {
        await clearTokens()
        await MainActor.run {
            authState = .unauthenticated
            currentUser = nil
        }
    }

    // MARK: - Token Management

    /// Save auth response to keychain
    private func saveAuthResponse(_ response: AuthResponse) async throws {
        // Save tokens
        try await saveToKeychain(key: accessTokenKey, value: response.accessToken)
        try await saveToKeychain(key: refreshTokenKey, value: response.refreshToken)

        // Save user info
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let userInfoData = try encoder.encode(response.user)
        try await saveToKeychain(key: userInfoKey, data: userInfoData)

        // Update state
        await MainActor.run {
            authState = .authenticated(userId: response.user.id, tier: response.user.tier)
            currentUser = response.user
        }

        print("✅ [Auth] Logged in as \(response.user.email) (\(response.user.tier))")
    }

    /// Get access token from keychain
    func getAccessToken() async -> String? {
        return await getFromKeychain(key: accessTokenKey)
    }

    /// Get refresh token from keychain
    func getRefreshToken() async -> String? {
        return await getFromKeychain(key: refreshTokenKey)
    }

    /// Get user info from keychain
    func getUserInfo() async -> UserInfo? {
        guard let data = await getDataFromKeychain(key: userInfoKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UserInfo.self, from: data)
    }

    /// Refresh access token using refresh token
    func refreshAccessToken() async throws {
        guard let refreshToken = await getRefreshToken() else {
            throw NetworkError.unauthorized
        }

        struct RefreshRequest: Codable {
            let refreshToken: String
        }

        let request = RefreshRequest(refreshToken: refreshToken)
        let response: AuthResponse = try await NetworkService.shared.post(
            "/auth/refresh",
            body: request
        )

        try await saveAuthResponse(response)
    }

    /// Clear all tokens from keychain
    func clearTokens() async {
        await deleteFromKeychain(key: accessTokenKey)
        await deleteFromKeychain(key: refreshTokenKey)
        await deleteFromKeychain(key: userInfoKey)
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(key: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to encode value"
            ])
        }
        try await saveToKeychain(key: key, data: data)
    }

    private func saveToKeychain(key: String, data: Data) async throws {
        // Delete existing item first
        await deleteFromKeychain(key: key)

        // Add new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw NSError(domain: "AuthManager", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to save to keychain: \(status)"
            ])
        }
    }

    private func getFromKeychain(key: String) async -> String? {
        guard let data = await getDataFromKeychain(key: key),
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func getDataFromKeychain(key: String) async -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return data
    }

    private func deleteFromKeychain(key: String) async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - User Tier

    /// Get current subscription tier
    func getCurrentTier() async -> SubscriptionTier {
        guard let userInfo = await getUserInfo() else {
            return .free
        }
        return userInfo.subscriptionTier
    }

    /// Check if user is authenticated
    func isAuthenticated() async -> Bool {
        return await getAccessToken() != nil
    }
}
