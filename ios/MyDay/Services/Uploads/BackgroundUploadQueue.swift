import Foundation

/// Delegate notified about changes to items within the background upload queue.
public protocol UploadQueueDelegate: AnyObject {
    func uploadQueue(_ queue: BackgroundUploadQueue, didUpdate item: UploadItem)
    func uploadQueue(_ queue: BackgroundUploadQueue, didComplete item: UploadItem)
    func uploadQueue(_ queue: BackgroundUploadQueue, didFail item: UploadItem, error: Error)
}

/// Encapsulates metadata for a file awaiting upload to the server.
public struct UploadItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let entryID: UUID
    public let fileURL: URL
    public let uploadURL: URL
    public var attempt: Int
    public var lastAttemptDate: Date?
    public var nextRetryDate: Date?

    public init(
        id: UUID = UUID(),
        entryID: UUID,
        fileURL: URL,
        uploadURL: URL,
        attempt: Int = 0,
        lastAttemptDate: Date? = nil,
        nextRetryDate: Date? = nil
    ) {
        self.id = id
        self.entryID = entryID
        self.fileURL = fileURL
        self.uploadURL = uploadURL
        self.attempt = attempt
        self.lastAttemptDate = lastAttemptDate
        self.nextRetryDate = nextRetryDate
    }
}

/// Defines the exponential backoff policy applied to failed uploads.
public struct BackoffPolicy: Codable, Sendable {
    public var initial: TimeInterval
    public var multiplier: Double
    public var maxDelay: TimeInterval
    public var maxAttempts: Int

    public init(initial: TimeInterval = 5, multiplier: Double = 2.0, maxDelay: TimeInterval = 15 * 60, maxAttempts: Int = 5) {
        self.initial = initial
        self.multiplier = multiplier
        self.maxDelay = maxDelay
        self.maxAttempts = maxAttempts
    }

    public func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let delay = initial * pow(multiplier, Double(attempt - 1))
        return min(delay, maxDelay)
    }
}

/// Error emitted when the upload request finished but the server responded with a non-success status code.
public struct UploadHTTPError: Error {
    public let statusCode: Int
}

/// Handles background audio uploads using a `URLSession` configured for background delivery.
/// The queue persists state between launches, supports exponential backoff, and notifies a delegate
/// when uploads succeed or fail.
public final class BackgroundUploadQueue: NSObject {
    private let queueIdentifier = "com.yourdomain.myday.uploads"
    private let persistenceKey = "com.yourdomain.myday.uploads.state"

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: queueIdentifier)
        config.isDiscretionary = false
        config.allowsExpensiveNetworkAccess = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let fileManager: FileManager
    private let backoff: BackoffPolicy
    private let stateQueue = DispatchQueue(label: "com.yourdomain.myday.uploads.state", attributes: .concurrent)
    private var items: [UUID: UploadItem]
    private var taskIdentifiers: [Int: UUID]
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public weak var delegate: UploadQueueDelegate?

    public override init() {
        self.fileManager = .default
        self.backoff = BackoffPolicy()
        self.items = [:]
        self.taskIdentifiers = [:]
        super.init()
        loadPersistedItems()
        rehydrateTasks()
    }

    public init(fileManager: FileManager = .default, backoff: BackoffPolicy = BackoffPolicy()) {
        self.fileManager = fileManager
        self.backoff = backoff
        self.items = [:]
        self.taskIdentifiers = [:]
        super.init()
        loadPersistedItems()
        rehydrateTasks()
    }

    public func enqueue(entryID: UUID, fileURL: URL, uploadURL: URL) throws {
        var item = UploadItem(entryID: entryID, fileURL: fileURL, uploadURL: uploadURL)
        try scheduleUpload(for: &item)
    }

    public func retryDueUploads() {
        let dueItems: [UploadItem] = stateQueue.sync {
            items.values.filter { item in
                guard let nextRetry = item.nextRetryDate else { return true }
                return nextRetry <= Date()
            }
        }

        for var item in dueItems {
            try? scheduleUpload(for: &item)
        }
    }

    public func cancelUploads(for entryID: UUID) {
        stateQueue.async(flags: .barrier) {
            let ids = self.items.values.filter { $0.entryID == entryID }.map { $0.id }
            for id in ids {
                self.items.removeValue(forKey: id)
            }
            self.persistItems()
        }

        session.getAllTasks { tasks in
            tasks.filter { task in
                guard let id = self.taskIdentifiers[task.taskIdentifier],
                      self.items[id]?.entryID == entryID else { return false }
                return true
            }.forEach { $0.cancel() }
        }
    }

    public func hasPendingUpload(for entryID: UUID) -> Bool {
        stateQueue.sync {
            items.values.contains { $0.entryID == entryID }
        }
    }

    public func pendingEntryIDs() -> Set<UUID> {
        stateQueue.sync {
            Set(items.values.map { $0.entryID })
        }
    }

    private func scheduleUpload(for item: inout UploadItem) throws {
        guard fileManager.fileExists(atPath: item.fileURL.path) else { return }

        var request = URLRequest(url: item.uploadURL)
        request.httpMethod = "PUT"
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")

        let task = session.uploadTask(with: request, fromFile: item.fileURL)
        task.taskDescription = item.id.uuidString
        item.attempt += 1
        item.lastAttemptDate = Date()
        item.nextRetryDate = nil
        track(task: task, for: item)
        persist(item)
        DispatchQueue.main.async {
            self.delegate?.uploadQueue(self, didUpdate: item)
        }
        task.resume()
    }

    private func handleCompletion(for task: URLSessionTask, error: Error?) {
        let taskIdentifier = task.taskIdentifier
        guard let itemID = stateQueue.sync(execute: { taskIdentifiers[taskIdentifier] }) else { return }
        stateQueue.async(flags: .barrier) {
            guard var item = self.items[itemID] else { return }
            self.taskIdentifiers[taskIdentifier] = nil

            if let error {
                if item.attempt >= self.backoff.maxAttempts {
                    self.items.removeValue(forKey: itemID)
                    self.persistItems()
                    DispatchQueue.main.async {
                        self.delegate?.uploadQueue(self, didFail: item, error: error)
                    }
                } else {
                    let delay = self.backoff.delay(for: item.attempt)
                    item.nextRetryDate = Date().addingTimeInterval(delay)
                    self.items[itemID] = item
                    self.persistItems()
                    DispatchQueue.main.async {
                        self.delegate?.uploadQueue(self, didUpdate: item)
                    }
                }
            } else if let response = task.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
                let statusError = UploadHTTPError(statusCode: response.statusCode)
                if item.attempt >= self.backoff.maxAttempts {
                    self.items.removeValue(forKey: itemID)
                    self.persistItems()
                    DispatchQueue.main.async {
                        self.delegate?.uploadQueue(self, didFail: item, error: statusError)
                    }
                } else {
                    let delay = self.backoff.delay(for: item.attempt)
                    item.nextRetryDate = Date().addingTimeInterval(delay)
                    self.items[itemID] = item
                    self.persistItems()
                    DispatchQueue.main.async {
                        self.delegate?.uploadQueue(self, didUpdate: item)
                    }
                }
            } else {
                item.nextRetryDate = nil
                self.items.removeValue(forKey: itemID)
                self.persistItems()
                DispatchQueue.main.async {
                    self.delegate?.uploadQueue(self, didComplete: item)
                }
            }
        }
    }

    private func track(task: URLSessionTask, for item: UploadItem) {
        stateQueue.async(flags: .barrier) {
            self.items[item.id] = item
            self.taskIdentifiers[task.taskIdentifier] = item.id
            self.persistItems()
        }
    }

    private func persist(_ item: UploadItem) {
        stateQueue.async(flags: .barrier) {
            self.items[item.id] = item
            self.persistItems()
        }
    }

    private func persistItems() {
        let array = Array(items.values)
        if let data = try? encoder.encode(array) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func loadPersistedItems() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let persisted = try? decoder.decode([UploadItem].self, from: data) else { return }
        for item in persisted {
            items[item.id] = item
        }
    }

    private func rehydrateTasks() {
        session.getAllTasks { tasks in
            self.stateQueue.async(flags: .barrier) {
                var activeItemIDs = Set<UUID>()
                for task in tasks {
                    guard let description = task.taskDescription, let itemID = UUID(uuidString: description) else { continue }
                    self.taskIdentifiers[task.taskIdentifier] = itemID
                    activeItemIDs.insert(itemID)
                    if var item = self.items[itemID] {
                        item.nextRetryDate = nil
                        self.items[itemID] = item
                    }
                }

                let persistedIDs = Set(self.items.keys)
                let orphanedIDs = persistedIDs.subtracting(activeItemIDs)
                for itemID in orphanedIDs {
                    if var item = self.items[itemID] {
                        let delay = self.backoff.delay(for: max(item.attempt, 1))
                        item.nextRetryDate = Date().addingTimeInterval(delay)
                        self.items[itemID] = item
                    }
                }

                self.persistItems()
            }
        }
    }
}

extension BackgroundUploadQueue: URLSessionTaskDelegate, URLSessionDataDelegate {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        handleCompletion(for: task, error: error)
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(request)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {}
}
