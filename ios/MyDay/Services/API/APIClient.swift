import Foundation

public struct APIError: Error, LocalizedError {
    public let statusCode: Int
    public let data: Data?
    public let underlying: Error?

    public var errorDescription: String? {
        if let underlying = underlying {
            return underlying.localizedDescription
        }

        if let data = data, let body = String(data: data, encoding: .utf8) {
            return "Request failed with status code \(statusCode): \(body)"
        }

        return "Request failed with status code \(statusCode)"
    }
}

public struct APIRequest<Response: Decodable> {
    public var method: String
    public var path: String
    public var query: [URLQueryItem]
    public var body: Data?
    public var headers: [String: String]

    public init(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:]
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.headers = headers
    }
}

public protocol APIClientProtocol: Sendable {
    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response
}

public final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let accessTokenProvider: @Sendable () async throws -> String?

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        accessTokenProvider: @escaping @Sendable () async throws -> String?
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessTokenProvider = accessTokenProvider
    }

    public func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false)
        components?.queryItems = request.query.isEmpty ? nil : request.query
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let token = try await accessTokenProvider() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError(statusCode: 0, data: nil, underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(statusCode: 0, data: data, underlying: nil)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError(statusCode: httpResponse.statusCode, data: data, underlying: nil)
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        return try JSONDecoder.myDay.decode(Response.self, from: data)
    }
}

public struct EmptyResponse: Decodable {
    public init() {}
}

private extension JSONDecoder {
    static let myDay: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
