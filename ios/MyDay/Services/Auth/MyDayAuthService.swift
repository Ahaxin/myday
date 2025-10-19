import AuthenticationServices
import Foundation

public struct AuthTokens: Codable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date

    public var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-60)
    }
}

public protocol AuthNetworking: Sendable {
    func exchangeAppleToken(_ body: MyDayAuthService.AppleExchangeRequest) async throws -> AuthTokens
    func exchangeGoogleToken(_ body: MyDayAuthService.GoogleExchangeRequest) async throws -> AuthTokens
    func refreshTokens(_ body: MyDayAuthService.RefreshRequest) async throws -> AuthTokens
}

/// Coordinates Apple and Google sign-in flows, exchanges identity tokens with the backend,
/// and persists resulting access/refresh tokens in the Keychain.
public final class MyDayAuthService: NSObject, ObservableObject {
    public enum AuthError: Error {
        case missingIdentityToken
        case missingIDToken
    }

    public struct AppleExchangeRequest: Encodable {
        public let identityToken: String
        public let authorizationCode: String?
        public let user: String?
    }

    public struct GoogleExchangeRequest: Encodable {
        public let idToken: String
    }

    public struct RefreshRequest: Encodable {
        public let refreshToken: String
    }

    @Published public private(set) var tokens: AuthTokens?

    private let keychain: KeychainStoreProtocol
    private let keychainKey = "com.yourdomain.myday.tokens"
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let network: AuthNetworking

    public init(
        network: AuthNetworking,
        keychain: KeychainStoreProtocol
    ) {
        self.network = network
        self.keychain = keychain
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.jsonEncoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder
        super.init()
        loadTokensFromKeychain()
    }

    public func handleAppleAuthorization(result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let error):
            throw error
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthError.missingIdentityToken
            }

            guard let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                throw AuthError.missingIdentityToken
            }

            let body = AppleExchangeRequest(
                identityToken: identityToken,
                authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
                user: credential.user
            )

            let tokens = try await network.exchangeAppleToken(body)
            try persist(tokens)
        }
    }

    public func handleGoogleSignIn(idToken: String?) async throws {
        guard let idToken else { throw AuthError.missingIDToken }
        let tokens = try await network.exchangeGoogleToken(GoogleExchangeRequest(idToken: idToken))
        try persist(tokens)
    }

    public func refreshTokensIfNeeded() async throws {
        guard let tokens = tokens else { return }
        if tokens.isExpired {
            try await refreshTokens()
        }
    }

    public func refreshTokens() async throws {
        guard let tokens = tokens else { return }
        let refreshed = try await network.refreshTokens(RefreshRequest(refreshToken: tokens.refreshToken))
        try persist(refreshed)
    }

    public func accessToken() async throws -> String? {
        try await refreshTokensIfNeeded()
        return tokens?.accessToken
    }

    public func signOut() throws {
        tokens = nil
        try keychain.removeValue(for: keychainKey)
    }

    private func persist(_ tokens: AuthTokens) throws {
        let data = try jsonEncoder.encode(tokens)
        try keychain.set(data, for: keychainKey)
        Task { @MainActor in
            self.tokens = tokens
        }
    }

    private func loadTokensFromKeychain() {
        if let data = try? keychain.data(for: keychainKey),
           let storedTokens = try? jsonDecoder.decode(AuthTokens.self, from: data) {
            tokens = storedTokens
        }
    }
}
