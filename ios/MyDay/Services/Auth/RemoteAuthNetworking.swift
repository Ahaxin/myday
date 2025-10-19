import Foundation

/// API-backed implementation of `AuthNetworking` responsible for exchanging third-party identity tokens
/// for the app's access and refresh tokens.
public final class RemoteAuthNetworking: AuthNetworking {
    private let client: APIClientProtocol
    private let encoder: JSONEncoder

    public init(client: APIClientProtocol) {
        self.client = client
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func exchangeAppleToken(_ body: MyDayAuthService.AppleExchangeRequest) async throws -> AuthTokens {
        try await send(body: body, path: "/v1/auth/apple")
    }

    public func exchangeGoogleToken(_ body: MyDayAuthService.GoogleExchangeRequest) async throws -> AuthTokens {
        try await send(body: body, path: "/v1/auth/google")
    }

    public func refreshTokens(_ body: MyDayAuthService.RefreshRequest) async throws -> AuthTokens {
        try await send(body: body, path: "/v1/auth/refresh")
    }

    private func send<Body: Encodable>(body: Body, path: String) async throws -> AuthTokens {
        let data = try encoder.encode(body)
        let request = APIRequest<AuthTokens>(method: "POST", path: path, body: data)
        return try await client.send(request)
    }
}
