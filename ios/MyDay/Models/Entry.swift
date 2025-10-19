import Foundation

/// Lifecycle states for a recorded entry.
public enum EntryStatus: String, Codable, Sendable {
    case queued
    case uploading
    case uploaded
    case transcribing
    case transcribed
    case failed
}

/// Raw and cleaned transcripts delivered by the backend.
public struct Transcript: Codable, Sendable {
    public var raw: String?
    public var cleaned: String?

    public init(raw: String? = nil, cleaned: String? = nil) {
        self.raw = raw
        self.cleaned = cleaned
    }
}

/// Represents a diary entry recorded on device and mirrored to the backend.
public struct Entry: Identifiable, Codable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var duration: TimeInterval
    public var status: EntryStatus
    public var audioURL: URL?
    public var localFileURL: URL?
    public var sizeBytes: Int64
    public var transcript: Transcript
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        duration: TimeInterval,
        status: EntryStatus,
        audioURL: URL? = nil,
        localFileURL: URL? = nil,
        sizeBytes: Int64 = 0,
        transcript: Transcript = Transcript(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.status = status
        self.audioURL = audioURL
        self.localFileURL = localFileURL
        self.sizeBytes = sizeBytes
        self.transcript = transcript
        self.updatedAt = updatedAt
    }
}
