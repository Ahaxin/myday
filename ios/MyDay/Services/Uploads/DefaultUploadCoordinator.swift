import Foundation

/// Bridges the background upload queue with higher-level sync logic, translating delegate callbacks
/// into closures so the caller can update local persistence as uploads succeed or fail.
public final class DefaultUploadCoordinator: UploadCoordinator, UploadQueueDelegate {
    private let queue: BackgroundUploadQueue
    private var pendingEntryIDs: Set<UUID>
    private let stateQueue = DispatchQueue(label: "com.yourdomain.myday.uploads.coordinator", attributes: .concurrent)
    private let onComplete: @Sendable (UUID) -> Void
    private let onFailure: @Sendable (UUID, Error) -> Void

    public init(
        queue: BackgroundUploadQueue = BackgroundUploadQueue(),
        onComplete: @escaping @Sendable (UUID) -> Void,
        onFailure: @escaping @Sendable (UUID, Error) -> Void
    ) {
        self.queue = queue
        self.pendingEntryIDs = queue.pendingEntryIDs()
        self.onComplete = onComplete
        self.onFailure = onFailure
        self.queue.delegate = self
    }

    public func enqueue(entry: Entry, uploadURL: URL) throws {
        guard let fileURL = entry.localFileURL else { return }
        try queue.enqueue(entryID: entry.id, fileURL: fileURL, uploadURL: uploadURL)
        stateQueue.async(flags: .barrier) {
            self.pendingEntryIDs.insert(entry.id)
        }
    }

    public func hasPendingUpload(for entryID: UUID) -> Bool {
        stateQueue.sync { pendingEntryIDs.contains(entryID) || queue.hasPendingUpload(for: entryID) }
    }

    public func resumePendingUploads() {
        queue.retryDueUploads()
    }

    // MARK: - UploadQueueDelegate

    public func uploadQueue(_ queue: BackgroundUploadQueue, didUpdate item: UploadItem) {
        stateQueue.async(flags: .barrier) {
            self.pendingEntryIDs.insert(item.entryID)
        }
    }

    public func uploadQueue(_ queue: BackgroundUploadQueue, didComplete item: UploadItem) {
        stateQueue.async(flags: .barrier) {
            self.pendingEntryIDs.remove(item.entryID)
        }
        onComplete(item.entryID)
    }

    public func uploadQueue(_ queue: BackgroundUploadQueue, didFail item: UploadItem, error: Error) {
        stateQueue.async(flags: .barrier) {
            self.pendingEntryIDs.remove(item.entryID)
        }
        onFailure(item.entryID, error)
    }
}

extension DefaultUploadCoordinator: @unchecked Sendable {}
