import Foundation

public protocol EntryStore: Sendable {
    /// Returns entries whose audio still needs to be uploaded.
    func pendingEntries() async throws -> [Entry]
    /// Inserts or updates remote entries in local persistence.
    func upsert(entries: [Entry]) async throws
    /// Marks local entries as uploaded and clears any temporary flags.
    func markAsUploaded(_ entryIDs: [UUID]) async throws
    /// Updates status for a set of entries.
    func updateStatus(_ status: EntryStatus, for entryIDs: [UUID]) async throws
    /// Persists new transcript content for the specified entry.
    func updateTranscript(_ transcript: Transcript, for entryID: UUID) async throws
}

public protocol UploadCoordinator: Sendable {
    /// Enqueues the given entry for upload using a signed URL.
    func enqueue(entry: Entry, uploadURL: URL) throws
    /// Returns whether the entry already has an upload task in-flight or pending.
    func hasPendingUpload(for entryID: UUID) -> Bool
    /// Requests that any pending uploads be resumed if their backoff window has elapsed.
    func resumePendingUploads()
}

public protocol SyncNetworking: Sendable {
    /// Requests a signed PUT URL to upload audio for the entry.
    func requestUploadURL(for entryID: UUID) async throws -> URL
    /// Sends metadata about a pending entry (duration, size, status) to the backend.
    func submitEntryMetadata(_ entry: Entry) async throws
    /// Retrieves remote entries updated since the provided cursor.
    func fetchEntries(since: Date?) async throws -> [Entry]
}

/// Runs the client-side sync loop that uploads local entries and merges remote status/transcripts.
public actor SyncService {
    public enum SyncError: Error {
        case missingLocalFile
    }

    private let entryStore: EntryStore
    private let uploadCoordinator: UploadCoordinator
    private let network: SyncNetworking
    private var lastSyncDate: Date?

    public init(entryStore: EntryStore, uploadCoordinator: UploadCoordinator, network: SyncNetworking) {
        self.entryStore = entryStore
        self.uploadCoordinator = uploadCoordinator
        self.network = network
    }

    @discardableResult
    public func performSync() async throws -> [Entry] {
        uploadCoordinator.resumePendingUploads()
        let pending = try await entryStore.pendingEntries()
        try await uploadPendingEntries(pending)
        let remoteEntries = try await network.fetchEntries(since: lastSyncDate)
        try await merge(remoteEntries)
        lastSyncDate = Date()
        return remoteEntries
    }

    public func merge(_ entries: [Entry]) async throws {
        try await entryStore.upsert(entries: entries)
        let transcribed = entries.filter { $0.status == .transcribed }
        for entry in transcribed where entry.transcript.cleaned != nil {
            try await entryStore.updateTranscript(entry.transcript, for: entry.id)
        }
    }

    public func handleUploadSuccess(for entryID: UUID) async {
        do {
            try await entryStore.markAsUploaded([entryID])
            try await entryStore.updateStatus(.uploaded, for: [entryID])
        } catch {
            // Failure to update local state should not crash the sync loop.
        }
    }

    public func handleUploadFailure(for entryID: UUID, error: Error) async {
        do {
#if DEBUG
            print("Upload failed for entry \(entryID): \(error)")
#endif
            try await entryStore.updateStatus(.failed, for: [entryID])
        } catch {
            // Swallow errors to avoid recursive retries; callers can re-enqueue later.
        }
    }

    private func uploadPendingEntries(_ entries: [Entry]) async throws {
        for entry in entries {
            guard entry.localFileURL != nil else {
                throw SyncError.missingLocalFile
            }

            if uploadCoordinator.hasPendingUpload(for: entry.id) {
                continue
            }

            let uploadURL = try await network.requestUploadURL(for: entry.id)
            try await network.submitEntryMetadata(entry)
            try uploadCoordinator.enqueue(entry: entry, uploadURL: uploadURL)
            try await entryStore.updateStatus(.uploading, for: [entry.id])
        }
    }
}
