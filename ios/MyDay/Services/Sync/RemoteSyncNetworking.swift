import Foundation

/// Concrete `SyncNetworking` implementation backed by the REST API.
public final class RemoteSyncNetworking: SyncNetworking {
    private let client: APIClientProtocol
    private let encoder: JSONEncoder

    public init(client: APIClientProtocol) {
        self.client = client
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func requestUploadURL(for entryID: UUID) async throws -> URL {
        let path = "/v1/entries/\(entryID.uuidString)/upload-url"
        let response = try await client.send(APIRequest<UploadURLResponse>(method: "POST", path: path))
        guard let url = URL(string: response.uploadURL) else {
            throw URLError(.badURL)
        }
        return url
    }

    public func submitEntryMetadata(_ entry: Entry) async throws {
        let request = EntryMetadataRequest(entry: entry)
        let data = try encoder.encode(request)
        let path = "/v1/entries/\(entry.id.uuidString)"
        _ = try await client.send(APIRequest<EmptyResponse>(method: "PUT", path: path, body: data))
    }

    public func fetchEntries(since: Date?) async throws -> [Entry] {
        var query: [URLQueryItem] = []
        if let since {
            let formatter = ISO8601DateFormatter()
            query.append(URLQueryItem(name: "since", value: formatter.string(from: since)))
        }
        let request = APIRequest<[Entry]>(method: "GET", path: "/v1/entries", query: query)
        return try await client.send(request)
    }
}

private struct UploadURLResponse: Decodable {
    let uploadURL: String
}

private struct EntryMetadataRequest: Encodable {
    let id: UUID
    let createdAt: Date
    let duration: TimeInterval
    let status: EntryStatus
    let sizeBytes: Int64

    init(entry: Entry) {
        id = entry.id
        createdAt = entry.createdAt
        duration = entry.duration
        status = entry.status
        sizeBytes = entry.sizeBytes
    }
}
